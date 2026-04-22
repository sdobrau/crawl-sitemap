This program crawls a given sitemap or domain using gau and
mass-converts the HTML files to Org Mode. Having a local copy of the
documentation greatly helps in quickly sifting through for example
by using a grep program.

To use against sitemap XML:

`hh22oo-sitemap XML_URL_PATH`

Dependencies:

- `gau` (https://github.com/lc/gau)
- `XML-Twig`
- `HTML-TreeBuilder-XPath`
- `wget2`
- `parallel`
- `plocate`
- `pandoc`
