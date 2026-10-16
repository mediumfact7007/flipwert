'use strict';

const http = require('node:http');
const { ebayItems, handle } = require('./handler');

function toFetchRequest(request) {
  const protocol = request.socket.encrypted ? 'https' : 'http';
  const url = `${protocol}://${request.headers.host || 'localhost'}${request.url}`;
  const init = { method: request.method, headers: request.headers };
  if (request.method !== 'GET' && request.method !== 'HEAD') {
    init.body = request;
    init.duplex = 'half';
  }
  return new Request(url, init);
}

async function sendFetchResponse(response, target) {
  const body = Buffer.from(await response.arrayBuffer());
  const headers = Object.fromEntries(response.headers.entries());
  headers['content-length'] = String(body.length);
  target.writeHead(response.status, headers);
  target.end(body);
}

const server = http.createServer(async (request, response) => {
  try {
    await sendFetchResponse(
      await handle(toFetchRequest(request), process.env),
      response,
    );
  } catch (error) {
    const body = JSON.stringify({
      error: error instanceof Error ? error.message : String(error),
    });
    response.writeHead(500, {
      'content-type': 'application/json; charset=utf-8',
      'content-length': String(Buffer.byteLength(body)),
      'cache-control': 'no-store',
    });
    response.end(body);
  }
});

if (require.main === module) {
  const port = Number(process.env.PORT || 8080);
  server.listen(port, '0.0.0.0', () => {
    console.log(`Flipwert API listening on :${port}`);
  });
}

module.exports = { ebayItems, handle, server };
