"""Dev proxy that keeps a `flutter run -d web-server` session usable across
payment-gateway round trips.

The app is opened on http://localhost:8000 (the gateway's return / cancel URL)
while flutter serves on FLUTTER_PORT. Everything is piped through untouched
(including the debug service's websocket / SSE traffic), except the gateway's
return POST to an app page: flutter's dev server can't answer that, so it is
logged and answered with a 303 to the same path, with the posted form fields
added as query parameters, and the browser reloads the app with a GET.

Usage: python scripts/dev_payment_proxy.py [PROXY_PORT] [FLUTTER_PORT]
"""

import asyncio
import sys
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit

PROXY_PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
FLUTTER_PORT = int(sys.argv[2]) if len(sys.argv) > 2 else 8001


async def pipe(reader, writer):
    try:
        while data := await reader.read(65536):
            writer.write(data)
            await writer.drain()
    except (ConnectionError, asyncio.CancelledError):
        pass
    finally:
        writer.close()


def is_gateway_return(method, path):
    # Debug service endpoints ($dwdsSseHandler, ...) also use POST.
    return method == "POST" and not urlsplit(path).path.split("/")[-1].startswith("$")


async def handle(client_reader, client_writer):
    try:
        head = await client_reader.readuntil(b"\r\n\r\n")
    except (asyncio.IncompleteReadError, asyncio.LimitOverrunError, ConnectionError):
        client_writer.close()
        return

    lines = head.decode("latin-1").split("\r\n")
    method, path, _ = lines[0].split(" ", 2)
    headers = {k.strip().lower(): v.strip() for k, v in (l.split(":", 1) for l in lines[1:] if ":" in l)}

    if is_gateway_return(method, path):
        length = int(headers.get("content-length", 0) or 0)
        body = await client_reader.readexactly(length) if length else b""
        print(f"Gateway return: POST {path} ({length} bytes)")
        print(body[:500])

        url = urlsplit(path)
        query = parse_qsl(url.query) + parse_qsl(body.decode("utf-8", "replace"))
        location = urlunsplit(("", "", url.path, urlencode(query), ""))

        client_writer.write(
            f"HTTP/1.1 303 See Other\r\nLocation: {location}\r\n"
            "Content-Length: 0\r\nConnection: close\r\n\r\n".encode("latin-1")
        )
        await client_writer.drain()
        client_writer.close()
        return

    # One request per connection (unless upgraded to a websocket), so every
    # request on a reused browser connection still gets the check above.
    if "upgrade" not in headers:
        lines = [l for l in lines if not l.lower().startswith(("connection:", "keep-alive:"))]
        lines.insert(len(lines) - 2, "Connection: close")
        head = "\r\n".join(lines).encode("latin-1")

    try:
        upstream_reader, upstream_writer = await asyncio.open_connection("127.0.0.1", FLUTTER_PORT)
    except ConnectionError:
        client_writer.write(
            b"HTTP/1.1 502 Bad Gateway\r\nContent-Type: text/plain\r\nConnection: close\r\n\r\n"
            b"flutter run is not serving yet - refresh once it is."
        )
        await client_writer.drain()
        client_writer.close()
        return

    upstream_writer.write(head)
    await asyncio.gather(pipe(client_reader, upstream_writer), pipe(upstream_reader, client_writer))


async def main():
    server = await asyncio.start_server(handle, "127.0.0.1", PROXY_PORT)
    print(f"Open http://localhost:{PROXY_PORT}/ (proxying flutter on port {FLUTTER_PORT})")
    async with server:
        await server.serve_forever()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
