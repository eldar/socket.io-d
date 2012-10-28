import vibe.d;

import socketio.socketio;

import std.stdio;

void handleRequest(HttpServerRequest req,
                   HttpServerResponse res)
{
    res.render!("index.dt");
}

void logRequest(HttpServerRequest req, HttpServerResponse res)
{
    writefln("url: %s", req.url);
}

static this()
{
    auto io = new SocketIo();

    auto router = new UrlRouter;
    router
        .any("*", &logRequest)
        .any("*", &io.handleRequest)
        .get("/public/*", serveStaticFiles("./public/", new HttpFileServerSettings("/public/")))
        .get("/", &handleRequest);

    io.onConnection( (socket) {
        writefln("connected client: %s", socket.id);

        socket.on("news", (Json data) {
            writefln("got news: %s", data);
            socket.broadcast_emit("news", data);
        });
    });

    auto settings = new HttpServerSettings;
    settings.port = 8080;

    listenHttp(settings, router);
}
