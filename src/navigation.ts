import { getPermalink, getAsset } from './utils/permalinks';

export const headerData = {
  links: [
    {
      text: 'Village',
      links: [
        { text: 'About Mambakkam', href: getPermalink('/village') },
        { text: 'Land & Agriculture', href: getPermalink('/land') },
      ],
    },
    {
      text: 'Landmarks',
      href: getPermalink('/landmarks'),
    },
    {
      text: 'People',
      href: getPermalink('/people'),
    },
    {
      text: 'Work',
      links: [
        { text: 'Products', href: getPermalink('/work') },
        { text: 'Mentible', href: getPermalink('/mentible') },
        { text: 'Services', href: getPermalink('/services') },
      ],
    },
    {
      text: 'News',
      href: getPermalink('/news'),
    },
  ],
  actions: [],
};

export const footerData = {
  links: [
    {
      title: 'Village',
      links: [
        { text: 'About Mambakkam', href: getPermalink('/village') },
        { text: 'Landmarks', href: getPermalink('/landmarks') },
        { text: 'Land & Agriculture', href: getPermalink('/land') },
        { text: 'Temple', href: getPermalink('/landmarks/new-temple') },
      ],
    },
    {
      title: 'Community',
      links: [
        { text: 'People', href: getPermalink('/people') },
        { text: 'Products', href: getPermalink('/work') },
        { text: 'Services', href: getPermalink('/services') },
        { text: 'News & Updates', href: getPermalink('/news') },
      ],
    },
  ],
  secondaryLinks: [
    { text: 'Terms', href: getPermalink('/terms') },
    { text: 'Privacy Policy', href: getPermalink('/privacy') },
  ],
  socialLinks: [{ ariaLabel: 'RSS Feed', icon: 'tabler:rss', href: getAsset('/rss.xml') }],
  footNote: `© ${new Date().getFullYear()} Mambakkam &nbsp;·&nbsp; மாம்பாக்கம் &nbsp;·&nbsp; Kalavai Taluk, Ranipet District, Tamil Nadu`,
};
