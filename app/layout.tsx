import type { Metadata, Viewport } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";
import "./monetization.css";

const geist = Geist({ variable: "--font-geist", subsets: ["latin"] });
const mono = Geist_Mono({ variable: "--font-mono", subsets: ["latin"] });

export const metadata: Metadata = {
  title: "Konsens",
  description: "L’arène sociale de stratégie financière et de prédiction.",
  applicationName: "Konsens",
  manifest: "/manifest.webmanifest",
  icons: { icon: "/favicon.svg", apple: "/favicon.svg" },
  other: { "codex-preview": "development", "apple-mobile-web-app-capable": "yes" },
};

export const viewport: Viewport = { themeColor: "#07110f", width: "device-width", initialScale: 1, viewportFit: "cover" };

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="fr"><body className={`${geist.variable} ${mono.variable}`}>{children}</body></html>;
}
