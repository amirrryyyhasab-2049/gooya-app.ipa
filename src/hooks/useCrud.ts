"use client";

import { useCallback, useEffect, useRef, useState } from "react";

async function request<T>(url: string, init?: RequestInit): Promise<T> {
  const res = await fetch(url, {
    ...init,
    headers: { "Content-Type": "application/json", ...(init?.headers ?? {}) },
    cache: "no-store",
  });
  const data = (await res.json().catch(() => ({}))) as T & { error?: string };
  if (!res.ok) throw new Error(data.error || "خطایی رخ داد");
  return data;
}

/**
 * هوک عمومی CRUD با به‌روزرسانی خوش‌بینانه (optimistic) و بازگشت خودکار در صورت خطا.
 */
export function useCrud<T extends { id: number }>(endpoint: string, initialItems?: T[]) {
  const [items, setItems] = useState<T[]>(initialItems ?? []);
  const [loading, setLoading] = useState(!initialItems);
  const [error, setError] = useState<string | null>(null);
  const itemsRef = useRef(items);
  itemsRef.current = items;

  const refresh = useCallback(async () => {
    try {
      const data = await request<{ items: T[] }>(endpoint);
      setItems(data.items);
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : "خطا در دریافت اطلاعات");
    } finally {
      setLoading(false);
    }
  }, [endpoint]);

  useEffect(() => {
    if (!initialItems) void refresh();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [refresh]);

  const create = useCallback(
    async (payload: Record<string, unknown>, optimistic: Omit<T, "id">): Promise<T> => {
      const tempId = -Date.now();
      const temp = { ...optimistic, id: tempId } as T;
      setItems((prev) => [temp, ...prev]);
      try {
        const data = await request<{ item: T }>(endpoint, { method: "POST", body: JSON.stringify(payload) });
        setItems((prev) => prev.map((i) => (i.id === tempId ? data.item : i)));
        return data.item;
      } catch (err) {
        setItems((prev) => prev.filter((i) => i.id !== tempId));
        throw err;
      }
    },
    [endpoint],
  );

  const update = useCallback(
    async (id: number, payload: Record<string, unknown>, optimisticPatch?: Partial<T>): Promise<T> => {
      const snapshot = itemsRef.current;
      if (optimisticPatch) setItems((prev) => prev.map((i) => (i.id === id ? { ...i, ...optimisticPatch } : i)));
      try {
        const data = await request<{ item: T }>(`${endpoint}/${id}`, { method: "PATCH", body: JSON.stringify(payload) });
        setItems((prev) => prev.map((i) => (i.id === id ? data.item : i)));
        return data.item;
      } catch (err) {
        setItems(snapshot);
        throw err;
      }
    },
    [endpoint],
  );

  const remove = useCallback(
    async (id: number): Promise<void> => {
      const snapshot = itemsRef.current;
      setItems((prev) => prev.filter((i) => i.id !== id));
      try {
        await request<{ ok: boolean }>(`${endpoint}/${id}`, { method: "DELETE" });
      } catch (err) {
        setItems(snapshot);
        throw err;
      }
    },
    [endpoint],
  );

  return { items, setItems, loading, error, refresh, create, update, remove };
}

export { request as apiRequest };
