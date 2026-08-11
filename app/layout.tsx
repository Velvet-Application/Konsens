import type { Metadata, Viewport } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";
import "./finance-shell.css";
import "./experience-v2.css";
import "./worlds-v3.css";
import "./play-ultimate.css";
import "./finance-ultimate.css";
import "./network-v2.css";
import "./journey-v3.css";
import "./monetization.css";

const geist=Geist({variable:"--font-geist",subsets:["latin"]});const mono=Geist_Mono({variable:"--font-mono",subsets:["latin"]});
export const metadata:Metadata={title:"Konsens — Entraîne ton intelligence financière",description:"Chaque jour, Konsens entraîne ta capacité à prendre de meilleures décisions avec l’argent : comprendre, prédire, décider et apprendre, sans argent réel.",applicationName:"Konsens",manifest:"/manifest.webmanifest",icons:{icon:"/konsens-logo.png",apple:"/konsens-logo.png"},other:{"codex-preview":"development","apple-mobile-web-app-capable":"yes","apple-mobile-web-app-title":"Konsens"}};
export const viewport:Viewport={themeColor:"#050d13",width:"device-width",initialScale:1,viewportFit:"cover"};
export default function RootLayout({children}:Readonly<{children:React.ReactNode}>){return <html lang="fr"><body className={`${geist.variable} ${mono.variable}`}>{children}</body></html>}
