import type { Config } from "tailwindcss";
import typography from "@tailwindcss/typography";

const config: Config = {
  content: ["./app/**/*.{ts,tsx}", "./components/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        ink: "#101A17",
        paper: "#F6F5EF",
        panel: "#FFFFFF",
        signal: "#1F6F4A", // deep employable-green, the "you got hired" accent
        signalDark: "#154E33",
        amber: "#C77D2E", // in-progress / pending states
        line: "#DCD8C8",
      },
      fontFamily: {
        display: ["'Fraunces'", "serif"],
        body: ["'Inter'", "sans-serif"],
        mono: ["'IBM Plex Mono'", "monospace"],
      },
      borderRadius: {
        sm: "4px",
        DEFAULT: "6px",
      },
    },
  },
  plugins: [typography],
};
export default config;
