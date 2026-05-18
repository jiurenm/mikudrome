interface StatusBannerProps {
  tone: "error" | "success";
  message: string;
}

export function StatusBanner({ tone, message }: StatusBannerProps) {
  return (
    <p className={`status-banner status-banner--${tone}`} role={tone === "error" ? "alert" : "status"}>
      {message}
    </p>
  );
}
