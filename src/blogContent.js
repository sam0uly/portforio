import rawPosts from 'virtual:blog-posts';

export function loadBlogPosts(locale) {
  const dateFmt = new Intl.DateTimeFormat(locale, {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
    timeZone: 'UTC',
  });

  return rawPosts.map((post) => {
    const parsedDate = new Date(`${post.dateIso}T00:00:00Z`);
    const dateLabel = Number.isNaN(parsedDate.getTime())
      ? post.dateIso
      : dateFmt.format(parsedDate);
    return { ...post, dateLabel };
  });
}
