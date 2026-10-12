import { readFile } from "node:fs/promises";
import path from "node:path";

import { ImageResponse } from "next/og";

export const alt =
  "Peony. One VPN at a time, from the menu bar. Beside it, Peony's panel connected to a VPN, with reachable hosts listed.";
export const size = { height: 630, width: 1200 };
export const contentType = "image/png";

// The site's light tokens, written out: this image renders outside the stylesheet.
const paper = "#fcfbfb";
const ink = "#1c0d12";
const gray = "#5c5357";
const rose = "#c85c7c";

const OUTER =
  "M15.38 10.4Q16 10.96 16.62 10.4C18.62 9.15 22.24 6.86 22.24 3.74C22.12 -1.35 9.88 -1.35 9.76 3.74C9.76 6.86 13.38 9.15 15.38 10.4ZM21.13 13.68Q20.79 14.44 21.52 14.86C23.32 16.38 26.62 19.11 29.58 18.15C34.39 16.45 30.61 4.82 25.73 6.28C22.76 7.24 21.7 11.39 21.13 13.68ZM19.8 20.16Q18.96 20.08 18.79 20.9C17.9 23.08 16.32 27.06 18.16 29.58C21.25 33.63 31.15 26.44 28.25 22.25C26.42 19.72 22.15 20 19.8 20.16ZM13.21 20.9Q13.04 20.08 12.2 20.16C9.85 20 5.58 19.72 3.75 22.25C0.85 26.44 10.75 33.63 13.84 29.58C15.68 27.06 14.1 23.08 13.21 20.9ZM10.48 14.86Q11.21 14.44 10.87 13.68C10.3 11.39 9.24 7.24 6.27 6.28C1.39 4.82 -2.39 16.45 2.42 18.15C5.38 19.11 8.68 16.38 10.48 14.86Z";
const INNER =
  "M16.51 14.99Q16.56 15.23 16.81 15.2C17.57 15.16 18.85 15.2 19.56 14.23C20.75 12.53 17.83 10.41 16.58 12.07C15.88 13.04 16.32 14.25 16.51 14.99ZM17.12 16.17Q16.91 16.29 17.01 16.52C17.28 17.23 17.64 18.47 18.78 18.84C20.77 19.45 21.88 16.02 19.92 15.34C18.78 14.97 17.76 15.76 17.12 16.17ZM16.18 17.12Q16 16.95 15.82 17.12C15.23 17.6 14.16 18.32 14.16 19.52C14.2 21.6 17.8 21.6 17.84 19.52C17.84 18.32 16.77 17.6 16.18 17.12ZM14.99 16.52Q15.09 16.29 14.88 16.17C14.24 15.76 13.22 14.97 12.08 15.34C10.12 16.02 11.23 19.45 13.22 18.84C14.36 18.47 14.72 17.23 14.99 16.52ZM15.19 15.2Q15.44 15.23 15.49 14.99C15.68 14.25 16.12 13.04 15.42 12.07C14.17 10.41 11.25 12.53 12.44 14.23C13.15 15.2 14.43 15.16 15.19 15.2Z";

const asset = (name: string) =>
  readFile(path.join(process.cwd(), "assets", name));

const Image = async () => {
  const [newsreader, geist, panel] = await Promise.all([
    asset("newsreader-500.woff"),
    asset("geist-400.woff"),
    readFile(
      path.join(
        process.cwd(),
        "../macos/Design/snapshots/panel-live-light.png"
      ),
      "base64"
    ),
  ]);

  return new ImageResponse(
    <div
      style={{
        backgroundColor: paper,
        border: `12px solid ${rose}`,
        color: ink,
        display: "flex",
        height: "100%",
        width: "100%",
      }}
    >
      <div
        style={{
          display: "flex",
          flexDirection: "column",
          justifyContent: "space-between",
          padding: "64px 0 64px 72px",
          width: 600,
        }}
      >
        <div style={{ alignItems: "center", display: "flex", gap: 16 }}>
          <svg width="52" height="52" viewBox="0 0 32 32" fill={rose}>
            <path d={INNER} />
            <path d={OUTER} />
          </svg>
          <div
            style={{
              fontFamily: "Newsreader",
              fontSize: 48,
              letterSpacing: "-0.035em",
            }}
          >
            Peony
          </div>
        </div>
        <div style={{ display: "flex", flexDirection: "column" }}>
          <div
            style={{
              fontFamily: "Newsreader",
              fontSize: 64,
              letterSpacing: "-0.035em",
              lineHeight: 1.08,
            }}
          >
            One VPN at a time.
          </div>
          <div
            style={{
              color: gray,
              fontFamily: "Geist",
              fontSize: 28,
              letterSpacing: "-0.01em",
              lineHeight: 1.4,
              marginTop: 24,
            }}
          >
            Switch between them from the menu bar, and know the hosts you need
            are reachable.
          </div>
        </div>
      </div>

      <div
        style={{
          backgroundColor: "#5a2136",
          backgroundImage:
            "radial-gradient(circle at 18% 20%, #f0b4c6 0%, rgba(240,180,198,0) 46%), radial-gradient(circle at 86% 84%, #c85c7c 0%, rgba(200,92,124,0) 52%), radial-gradient(circle at 70% 22%, #7a2e4a 0%, rgba(122,46,74,0) 60%)",
          display: "flex",
          flex: 1,
          justifyContent: "center",
          marginLeft: 48,
          overflow: "hidden",
          paddingTop: 56,
        }}
      >
        <img
          alt=""
          src={`data:image/png;base64,${panel}`}
          width={384}
          height={587}
          style={{
            borderRadius: 18,
            boxShadow: "0 28px 56px rgba(0, 0, 0, 0.35)",
          }}
        />
      </div>
    </div>,
    {
      ...size,
      fonts: [
        { data: newsreader, name: "Newsreader", style: "normal", weight: 500 },
        { data: geist, name: "Geist", style: "normal", weight: 400 },
      ],
    }
  );
};

export default Image;
