import type { Metadata } from "next";
import "./globals.css";
export const metadata: Metadata = {
  title: "Fluent — angielski w Twoim rytmie",
  description:
    "Twoje słowa, ich znaczenia i krótkie sesje, które pomagają zapamiętać na dłużej.",
  manifest: "/manifest.webmanifest",
  icons: { icon: "/favicon.svg", apple: "/icon-192.png" },
};
export default function Layout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="pl" suppressHydrationWarning>
      <body>{children}</body>
    </html>
  );
}
