/**
 * DownloadDictionary.tsx
 * =======================
 * "Download Dictionary" page for offline usage.
 * Users can download word packs to use the app without internet.
 */

import { useState, useEffect } from "react";
import { dictionary, DownloadPack } from "./DictionaryService";

interface Pack {
  id: DownloadPack;
  label: string;
  size: string;
  words: string;
  description: string;
  icon: string;
}

const PACKS: Pack[] = [
  {
    id:          "starter",
    label:       "Starter Pack",
    size:        "~100KB",
    words:       "5,000 words",
    description: "Most common everyday words. Perfect for beginners.",
    icon:        "🌱",
  },
  {
    id:          "standard",
    label:       "Standard Pack",
    size:        "~400KB",
    words:       "20,000 words",
    description: "Covers 99% of text you'll ever read. Recommended.",
    icon:        "📚",
  },
  {
    id:          "full",
    label:       "Full Dictionary",
    size:        "~2MB",
    words:       "100,000+ words",
    description: "Complete English-Uzbek dictionary. For power users.",
    icon:        "🏆",
  },
];

export default function DownloadDictionary() {
  const [downloaded, setDownloaded] = useState<Record<DownloadPack, boolean>>({
    starter: false, standard: false, full: false,
  });
  const [downloading, setDownloading] = useState<DownloadPack | null>(null);
  const [progress, setProgress]       = useState(0);
  const [cachedCount, setCachedCount] = useState(0);

  useEffect(() => {
    (async () => {
      const packs = await dictionary.getDownloadedPacks();
      setDownloaded(packs);
      const count = await dictionary.getCachedWordCount();
      setCachedCount(count);
    })();
  }, []);

  async function handleDownload(pack: DownloadPack) {
    setDownloading(pack);
    setProgress(0);

    try {
      const result = await dictionary.downloadPack(pack, (pct) => {
        setProgress(Math.round(pct));
      });

      if (result.success) {
        setDownloaded((prev) => ({ ...prev, [pack]: true }));
        const count = await dictionary.getCachedWordCount();
        setCachedCount(count);
      }
    } catch (e) {
      alert("Download failed. Please check your internet connection.");
      console.error(e);
    } finally {
      setDownloading(null);
      setProgress(0);
    }
  }

  return (
    <div style={styles.container}>
      <h1 style={styles.title}>📥 Download Dictionary</h1>
      <p style={styles.subtitle}>
        Download word packs to use VocabGame fully offline.
      </p>

      {/* Offline status banner */}
      <div style={styles.statusBanner}>
        <span style={styles.statusDot} />
        <span>
          {cachedCount > 0
            ? `${cachedCount.toLocaleString()} words available offline`
            : "No words downloaded yet — you need internet for lookups"}
        </span>
      </div>

      {/* Pack cards */}
      <div style={styles.packList}>
        {PACKS.map((pack) => {
          const isDone        = downloaded[pack.id];
          const isDownloading = downloading === pack.id;

          return (
            <div key={pack.id} style={styles.packCard}>
              <div style={styles.packHeader}>
                <span style={styles.packIcon}>{pack.icon}</span>
                <div>
                  <div style={styles.packLabel}>{pack.label}</div>
                  <div style={styles.packMeta}>
                    {pack.words} · {pack.size}
                  </div>
                </div>
                {isDone && <span style={styles.checkmark}>✅</span>}
              </div>

              <p style={styles.packDesc}>{pack.description}</p>

              {/* Progress bar (shown while downloading) */}
              {isDownloading && (
                <div style={styles.progressBar}>
                  <div style={{ ...styles.progressFill, width: `${progress}%` }} />
                </div>
              )}
              {isDownloading && (
                <div style={styles.progressLabel}>{progress}% downloaded...</div>
              )}

              <button
                style={{
                  ...styles.btn,
                  ...(isDone ? styles.btnDone : {}),
                  ...(isDownloading ? styles.btnLoading : {}),
                }}
                onClick={() => !isDone && !isDownloading && handleDownload(pack.id)}
                disabled={isDone || !!downloading}
              >
                {isDone
                  ? "Downloaded ✓"
                  : isDownloading
                  ? `Downloading... ${progress}%`
                  : `Download ${pack.label}`}
              </button>
            </div>
          );
        })}
      </div>

      {/* Info section */}
      <div style={styles.infoBox}>
        <p style={styles.infoText}>
          💡 <strong>How it works:</strong> Downloaded words are stored on your device.
          After downloading, those words are instantly available with no internet needed.
          The app also automatically caches any word you look up.
        </p>
      </div>
    </div>
  );
}

// ── Styles ────────────────────────────────────────────────────────────────────
const styles: Record<string, React.CSSProperties> = {
  container: {
    maxWidth: 480,
    margin: "0 auto",
    padding: "24px 16px 100px",
    color: "#fff",
  },
  title: {
    fontSize: 22,
    fontWeight: 700,
    marginBottom: 6,
  },
  subtitle: {
    color: "#aaa",
    fontSize: 14,
    marginBottom: 20,
  },
  statusBanner: {
    display: "flex",
    alignItems: "center",
    gap: 8,
    background: "#1e1e3a",
    borderRadius: 10,
    padding: "10px 14px",
    fontSize: 13,
    marginBottom: 24,
    color: "#ccc",
  },
  statusDot: {
    width: 8,
    height: 8,
    borderRadius: "50%",
    background: "#7c3aed",
    flexShrink: 0,
  },
  packList: {
    display: "flex",
    flexDirection: "column",
    gap: 16,
  },
  packCard: {
    background: "#1a1a2e",
    borderRadius: 14,
    padding: 18,
    border: "1px solid #2d2d50",
  },
  packHeader: {
    display: "flex",
    alignItems: "center",
    gap: 12,
    marginBottom: 10,
  },
  packIcon: {
    fontSize: 28,
  },
  packLabel: {
    fontWeight: 600,
    fontSize: 15,
  },
  packMeta: {
    color: "#888",
    fontSize: 12,
    marginTop: 2,
  },
  checkmark: {
    marginLeft: "auto",
    fontSize: 18,
  },
  packDesc: {
    color: "#aaa",
    fontSize: 13,
    marginBottom: 14,
    lineHeight: 1.4,
  },
  progressBar: {
    background: "#2d2d50",
    borderRadius: 99,
    height: 6,
    overflow: "hidden",
    marginBottom: 6,
  },
  progressFill: {
    height: "100%",
    background: "linear-gradient(90deg, #7c3aed, #a855f7)",
    borderRadius: 99,
    transition: "width 0.3s ease",
  },
  progressLabel: {
    fontSize: 12,
    color: "#888",
    marginBottom: 10,
    textAlign: "center",
  },
  btn: {
    width: "100%",
    padding: "12px 0",
    borderRadius: 10,
    border: "none",
    background: "linear-gradient(135deg, #7c3aed, #a855f7)",
    color: "#fff",
    fontWeight: 600,
    fontSize: 14,
    cursor: "pointer",
  },
  btnDone: {
    background: "#2d2d50",
    color: "#888",
    cursor: "default",
  },
  btnLoading: {
    opacity: 0.7,
    cursor: "default",
  },
  infoBox: {
    marginTop: 28,
    background: "#1e1e3a",
    borderRadius: 12,
    padding: 14,
  },
  infoText: {
    fontSize: 13,
    color: "#aaa",
    lineHeight: 1.5,
    margin: 0,
  },
};
