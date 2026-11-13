// Local unit-test safeguard; never reads credentials or contacts providers.
const blocked = () => { throw new Error('CHECKPOINT_NETWORK_DISABLED'); };
globalThis.fetch = blocked;
require('node:http').request = blocked;
require('node:http').get = blocked;
require('node:https').request = blocked;
require('node:https').get = blocked;
require('node:net').connect = blocked;
require('node:net').createConnection = blocked;
require('node:tls').connect = blocked;
require('node:dns').lookup = blocked;
require('node:dns').resolve = blocked;
