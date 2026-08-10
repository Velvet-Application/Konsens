import FinanceShell from "./finance-shell";
import MonetizationLayer from "./monetization-layer";

// Cloudflare frontend deployment marker: finance-v1
export default function Home() {
  return <MonetizationLayer><FinanceShell /></MonetizationLayer>;
}
