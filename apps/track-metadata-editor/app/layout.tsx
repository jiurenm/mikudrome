import type { Metadata } from "next";
import type { ReactNode } from "react";
import "../src/styles/global.css";

export const metadata: Metadata = {
  title: "Track Metadata Editor",
  description: "Edit track metadata through the backend API proxy."
};

interface RootLayoutProps {
  children: ReactNode;
}

export default function RootLayout({ children }: RootLayoutProps) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
