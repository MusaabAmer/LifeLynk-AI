import Image from "next/image";

export default function Loading() {
  return (
    <main className="lifelynk-loading">
      <div className="lifelynk-loading__content">
        <div className="lifelynk-loading__logo-wrap">
          <Image
            src="/images/app_icon.png"
            alt="LifeLynk"
            width={96}
            height={96}
            className="lifelynk-loading__logo"
          />
        </div>

        <div
          className="lifelynk-loading__spinner"
          aria-label="Loading"
        />

        <p className="lifelynk-loading__text">
          Connecting to LifeLynk AI
        </p>
      </div>
    </main>
  );
}