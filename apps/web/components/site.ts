import app from "../../macos/package.json";

const repo = "https://github.com/PunGrumpy/peony";
const production = process.env.VERCEL_PROJECT_PRODUCTION_URL;

export const site = {
  author: {
    name: "Noppakorn Kaewsalabnil",
    url: "https://www.pungrumpy.com",
  },
  brew: "brew install --cask pungrumpy/tap/peony",
  download: `${repo}/releases/download/v${app.version}/Peony-${app.version}.dmg`,
  license: `${repo}/blob/main/LICENSE`,
  releases: `${repo}/releases`,
  repo,
  url: production ? `https://${production}` : "http://localhost:3000",
  version: app.version,
};

// Pulse ships as Ivanti's wordmark, so its logo runs wide.
export const vpns = [
  { id: "fortigate", name: "FortiGate" },
  { id: "anyconnect", name: "AnyConnect" },
  { id: "globalprotect", name: "GlobalProtect" },
  { id: "pulse", name: "Pulse", wide: true },
  { id: "f5", name: "F5" },
  { id: "wireguard", name: "WireGuard" },
  { id: "netbird", name: "NetBird" },
] as const;

export const clients = [
  { command: "brew install openfortivpn", vpn: "FortiGate SSL-VPN" },
  {
    command: "brew install openconnect",
    vpn: "AnyConnect, GlobalProtect, Pulse, F5, Array",
  },
  { command: "brew install wireguard-tools", vpn: "WireGuard" },
] as const;

export const netbird = "https://docs.netbird.io/how-to/installation";
