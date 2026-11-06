import type { Metadata, Viewport } from "next";
import type { ReactNode } from "react";
import "./globals.css";
import { ToastProvider } from "@/components/toast";
import { PwaRegister } from "@/components/pwa-register";

export const metadata: Metadata = {
  title: {
    default: "گویا — تبدیل نوشتار به گفتار فارسی",
    template: "%s | گویا",
  },
  description: "متن فارسی خود را با صدایی طبیعی، روان و شمرده بشنوید؛ با اعراب‌گذاری خودکار و چند گویندهٔ دلنشین.",
  manifest: "/manifest.webmanifest",
  applicationName: "گویا",
  appleWebApp: { capable: true, title: "گویا", statusBarStyle: "black-translucent" },
  icons: { icon: "/icons/icon-192.png", apple: "/icons/apple-touch-icon.png" },
};

export const viewport: Viewport = {
  themeColor: "#312e81",
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="fa" dir="rtl">
      <body className="min-h-screen bg-slate-50 text-slate-900 antialiased">
        <ToastProvider>
          {children}
          <PwaRegister />
        </ToastProvider>
      </body>
    </html>
  );
}
