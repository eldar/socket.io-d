import vibe.d;

import socketio;

import std.stdio;

void handleRequest(HttpServerRequest req,
                   HttpServerResponse res)
{
    res.render!("index.dt");
}

void logRequest(HttpServerRequest req, HttpServerResponse res)
{
    //writefln("url: %s", req.url);
}

static this()
{
    auto router = new UrlRouter;
    router.any("*", &logRequest);

    auto io = new SocketIo(router);

    router
        .get("/public/*", serveStaticFiles("./public/", new HttpFileServerSettings("/public/")))
        .get("/", &handleRequest);

    io.onConnection( (socket) {

        socket.onMessage( (data) {
            socket.broadcast(data);
        });
    });

    auto settings = new HttpServerSettings;
    settings.port = 8080;

    listenHttp(settings, router);
}