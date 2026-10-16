import serverHandler from '../server/handler.js';

const { handle } = serverHandler;

export default {
  fetch(request, env) {
    return handle(request, env);
  },
};

