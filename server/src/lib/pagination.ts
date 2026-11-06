export type PageParams = {
  page: number;
  pageSize: number;
  skip: number;
  take: number;
};

/** Reads `page` and `pageSize` from an Express query object. */
export function pageParams(
  query: Record<string, unknown>,
  defaultSize: number,
  maxSize: number,
): PageParams {
  const rawPage = typeof query.page === "string" ? Number.parseInt(query.page, 10) : NaN;
  const rawSize =
    typeof query.pageSize === "string" ? Number.parseInt(query.pageSize, 10) : NaN;
  const page = Number.isFinite(rawPage) && rawPage > 0 ? rawPage : 1;
  const pageSize =
    Number.isFinite(rawSize) && rawSize > 0
      ? Math.min(rawSize, maxSize)
      : defaultSize;
  return { page, pageSize, skip: (page - 1) * pageSize, take: pageSize };
}

export function pageMeta(total: number, paging: PageParams) {
  return {
    total,
    page: paging.page,
    pageSize: paging.pageSize,
    hasMore: paging.page * paging.pageSize < total,
  };
}
