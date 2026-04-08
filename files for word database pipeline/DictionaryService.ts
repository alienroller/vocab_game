/**
 * DictionaryService.ts
 * ====================
 * Tiered offline-first dictionary lookup for VocabGame.
 *
 * Tier 1: Bundled top-5,000 words  → instant, always available
 * Tier 2: IndexedDB cache          → instant for previously searched words
 * Tier 3: Supabase cloud           → full 100,000+ word database
 *
 * "Download Dictionary" packs are stored in IndexedDB:
 *   - Starter pack  : top 5,000  words (~100KB)
 *   - Standard pack : top 20,000 words (~400KB)
 *   - Full pack     : all words  (~2MB)
 */

import { createClient } from "@supabase/supabase-js";

// ── Types ────────────────────────────────────────────────────────────────────
export interface WordEntry {
  english: string;
  uzbek: string;
  part_of_speech: string;
  definition: string;
  example: string;
  frequency_rank: number;
}

export type DownloadPack = "starter" | "standard" | "full";

// ── Config ───────────────────────────────────────────────────────────────────
const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL;
const SUPABASE_KEY = import.meta.env.VITE_SUPABASE_ANON_KEY;
const TABLE        = "dictionary_words";

const DB_NAME      = "VocabGameDB";
const DB_VERSION   = 1;
const CACHE_STORE  = "word_cache";
const PACKS_STORE  = "downloaded_packs";

const PACK_LIMITS: Record<DownloadPack, number> = {
  starter:  5_000,
  standard: 20_000,
  full:     999_999,
};

// ── Supabase client ───────────────────────────────────────────────────────────
const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);


// ── IndexedDB helpers ─────────────────────────────────────────────────────────
class IDBService {
  private db: IDBDatabase | null = null;

  async open(): Promise<IDBDatabase> {
    if (this.db) return this.db;
    return new Promise((resolve, reject) => {
      const req = indexedDB.open(DB_NAME, DB_VERSION);
      req.onupgradeneeded = (e) => {
        const db = (e.target as IDBOpenDBRequest).result;
        if (!db.objectStoreNames.contains(CACHE_STORE)) {
          const store = db.createObjectStore(CACHE_STORE, { keyPath: "english" });
          store.createIndex("uzbek", "uzbek", { unique: false });
        }
        if (!db.objectStoreNames.contains(PACKS_STORE)) {
          db.createObjectStore(PACKS_STORE, { keyPath: "pack" });
        }
      };
      req.onsuccess = (e) => {
        this.db = (e.target as IDBOpenDBRequest).result;
        resolve(this.db);
      };
      req.onerror = () => reject(req.error);
    });
  }

  async get(storeName: string, key: string): Promise<WordEntry | null> {
    const db  = await this.open();
    const tx  = db.transaction(storeName, "readonly");
    const store = tx.objectStore(storeName);
    return new Promise((resolve) => {
      const req = store.get(key);
      req.onsuccess = () => resolve(req.result ?? null);
      req.onerror   = () => resolve(null);
    });
  }

  async putMany(storeName: string, items: WordEntry[]): Promise<void> {
    const db    = await this.open();
    const tx    = db.transaction(storeName, "readwrite");
    const store = tx.objectStore(storeName);
    for (const item of items) {
      store.put(item);
    }
    return new Promise((resolve, reject) => {
      tx.oncomplete = () => resolve();
      tx.onerror    = () => reject(tx.error);
    });
  }

  async count(storeName: string): Promise<number> {
    const db    = await this.open();
    const tx    = db.transaction(storeName, "readonly");
    const store = tx.objectStore(storeName);
    return new Promise((resolve) => {
      const req = store.count();
      req.onsuccess = () => resolve(req.result);
      req.onerror   = () => resolve(0);
    });
  }

  /** Check if a download pack has been stored */
  async isPackDownloaded(pack: DownloadPack): Promise<boolean> {
    const record = await this.get(PACKS_STORE, pack);
    return record !== null;
  }

  async markPackDownloaded(pack: DownloadPack, wordCount: number): Promise<void> {
    const db    = await this.open();
    const tx    = db.transaction(PACKS_STORE, "readwrite");
    const store = tx.objectStore(PACKS_STORE);
    store.put({ pack, wordCount, downloadedAt: new Date().toISOString() });
  }
}

const idb = new IDBService();


// ── Main DictionaryService ────────────────────────────────────────────────────
export class DictionaryService {
  /** Bundled top-5000 words — loaded once at startup */
  private bundled: Map<string, WordEntry> = new Map();
  private bundleLoaded = false;

  /** Load the bundled top-5000 JSON (shipped with the app) */
  async loadBundle(): Promise<void> {
    if (this.bundleLoaded) return;
    try {
      const res  = await fetch("/top5000_bundle.json");
      const data: WordEntry[] = await res.json();
      for (const entry of data) {
        this.bundled.set(entry.english.toLowerCase(), entry);
      }
      this.bundleLoaded = true;
      console.log(`✅ Bundled dictionary: ${this.bundled.size} words`);
    } catch (e) {
      console.warn("⚠️ Could not load bundled dictionary", e);
    }
  }

  /**
   * Look up an English word.
   * Tries Tier 1 → Tier 2 → Tier 3 in order.
   */
  async lookup(word: string): Promise<WordEntry | null> {
    const key = word.toLowerCase().trim();
    if (!key) return null;

    // Tier 1: Bundled
    await this.loadBundle();
    if (this.bundled.has(key)) {
      return this.bundled.get(key)!;
    }

    // Tier 2: IndexedDB cache
    const cached = await idb.get(CACHE_STORE, key);
    if (cached) return cached;

    // Tier 3: Supabase
    try {
      const { data, error } = await supabase
        .from(TABLE)
        .select("*")
        .eq("english", key)
        .limit(1)
        .single();

      if (error || !data) return null;

      // Cache the result forever
      await idb.putMany(CACHE_STORE, [data as WordEntry]);
      return data as WordEntry;
    } catch (e) {
      console.error("Supabase lookup failed:", e);
      return null;
    }
  }

  /**
   * Search for words starting with a query string.
   * Used for autocomplete / search-as-you-type.
   */
  async search(query: string, limit = 10): Promise<WordEntry[]> {
    const key = query.toLowerCase().trim();
    if (!key) return [];

    // Search Supabase (full database)
    try {
      const { data } = await supabase
        .from(TABLE)
        .select("*")
        .ilike("english", `${key}%`)
        .order("frequency_rank", { ascending: true })
        .limit(limit);

      return (data as WordEntry[]) ?? [];
    } catch {
      // Offline fallback: search the bundle
      const results: WordEntry[] = [];
      for (const [eng, entry] of this.bundled) {
        if (eng.startsWith(key)) results.push(entry);
        if (results.length >= limit) break;
      }
      return results;
    }
  }

  /**
   * Download a word pack to IndexedDB for offline use.
   * Shows progress via the onProgress callback (0–100).
   */
  async downloadPack(
    pack: DownloadPack,
    onProgress?: (pct: number) => void
  ): Promise<{ success: boolean; wordCount: number }> {
    const limit     = PACK_LIMITS[pack];
    const batchSize = 1000;
    const allWords: WordEntry[] = [];

    onProgress?.(0);

    let from = 0;
    while (allWords.length < limit) {
      const to = Math.min(from + batchSize - 1, limit - 1);
      const { data, error } = await supabase
        .from(TABLE)
        .select("*")
        .order("frequency_rank", { ascending: true })
        .range(from, to);

      if (error || !data || data.length === 0) break;

      allWords.push(...(data as WordEntry[]));
      from += batchSize;

      const pct = Math.min((allWords.length / limit) * 100, 99);
      onProgress?.(pct);
    }

    // Store in IndexedDB
    await idb.putMany(CACHE_STORE, allWords);
    await idb.markPackDownloaded(pack, allWords.length);

    onProgress?.(100);
    console.log(`✅ Downloaded ${pack} pack: ${allWords.length} words`);
    return { success: true, wordCount: allWords.length };
  }

  /** Check which packs have been downloaded */
  async getDownloadedPacks(): Promise<Record<DownloadPack, boolean>> {
    return {
      starter:  await idb.isPackDownloaded("starter"),
      standard: await idb.isPackDownloaded("standard"),
      full:     await idb.isPackDownloaded("full"),
    };
  }

  /** Total words cached in IndexedDB */
  async getCachedWordCount(): Promise<number> {
    return idb.count(CACHE_STORE);
  }
}

// ── Singleton export ──────────────────────────────────────────────────────────
export const dictionary = new DictionaryService();
