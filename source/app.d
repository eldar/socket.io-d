import vibe.d;

import socketio;

void handleRequest(HttpServerRequest req,
                   HttpServerResponse res)
{
    res.render!("index.dt");
}

static this()
{
    auto io = new SocketIo;

    auto router = new UrlRouter;
    router
        .get("/public/*", serveStaticFiles("./public/", new HttpFileServerSettings("/public/")))
        .get("/socketio", &io.handleRequest)
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