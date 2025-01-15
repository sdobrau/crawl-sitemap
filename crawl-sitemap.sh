#!/usr/bin/env bash

function get-sitemap-urls-for-domain () {
  local url="${1}"
  local domain=${url/https:\/\/}
  echo "domain is $domain"
  local path="/tmp/${domain}-sitemap-crawler"
  mkdir -p $path
  echo "running 'gau' to find sitemap..."
  gau --threads 20 "${url}" | grep sitemap.xml
}

# TODO
function get-html-urls-for-domain () {
  local url="${1}"
  local domain=${url/https:\/\/}
  echo "domain is $domain"
  local path="/tmp/${domain}-sitemap-crawler"
  mkdir -p $path
  echo "running 'gau' to find sitemap..."
  gau --threads 50 --blacklist "/static/,pdk,sdk,images,png,jpg,gif,json,js,css,mp4,mp3,mpeg,sitemap,?ref" --fc 404,302 --mt text/html --subs
}

function retrieve-sitemaps-from-url-list () {
    local sitemap_urls_to_fetch="${1}"
    local prefix=$2

    # parallel
    wget2 -q --max-threads 20 -P "${prefix}-sitemaps" ${sitemap_urls_to_fetch[@]}
}

function get-urls-from-sitemap-list () {
  local sitemap_list="${1}"
  local -n result_array=$2
  # TODO: if csv
  echo "Grepping for URLs from site-map list.."
  result_array=$(xml_grep --cond 'loc' --text_only ${sitemap_list[@]})
}

function h2o () {
  local url="${1}"
  if [[ -z $url ]]; then
     echo "No URL supplied."
     return
  fi
  # for parallelism,
  local random_int=$RANDOM
  wget "${url}" -O page.html-$random_int 2>> ./wgeterrorout
  convert-html-file-to-clean-org page.html-$random_int
  rm -rf page.html-$random_int
}

function hh22oo () {
  pushd "${HOME}/org/stash"
  h2o "${1}"
}

function hh22oo-sitemap () {
  pushd "${HOME}/org/stash/stash2"
  h2o-sitemap $(wl-paste)
}

function h2o-sitemap () {
  local sitemap_url="${1}"
  wget ${1}
  declare -a my_urls
  local my_urls
  get-urls-from-sitemap-list sitemap.xml my_urls
  export -f h2o
  parallel h2o ::: ${my_urls[@]}
  rm -rf sitemap.xml
}

function convert-html-file-to-clean-org () {
  local html_file="${1}"
  # head -1: can’t select first element
  local title="$(xml_grep --html 'title' --text_only $html_file 2>> ./xmlgreperrorout | head -1)"
  # no ’/’s in filenames. replace with ’\’
  # no ’|’s in filenames either. replace with ’-’
  title=${title/\//\\}
  title=${title/\|/\-}

  echo "Converting to org..."
  echo -e "* ${title} \n" > "${title}.org"
  echo " " >> "${title}.org"
  # TODO: proper wrapping of org links (so they're not on multiple lines)
  # TODO: extract media and place as org
  pandoc --quiet --sandbox=true "${html_file}" --from html --to org \
         --wrap=preserve --columns=80 --toc=false \
         --strip-comments --tab-stop=2 --trace=false --shift-heading-level-by=1 1>> "${title}.org" 2>> ./panerrorout
  # rm -rf ${title}-extracted.md
}

function convert-to-org-for-domain () {
  local domain="${1}"
  declare -a retrieved_urls
  # 1. get sitemap urls
  local sitemap_urls=$(get-sitemap-urls-for-domain "${domain}")
  # 2. download the sitemaps into DOMAIN-sitemaps/sitemap.xml.1,.2...
  retrieve-sitemaps-from-url-list ${sitemap_urls[@]} "${domain}"
  # 3. retrieve html urls from each sitemap and append
  get-urls-from-sitemap-list ${domain-sitemaps}/*.xml retrieved_urls
  # 4. fetch all htmls from each sitemaps in ’DOMAIN-pages/’ directory
  echo "fetching all URLs..."
  # we append to file as the URL list may be too long for the cmdline
  for item in ${retrieved_urls[@]}; do
    echo "${item}" > retreived_url_list
  done
  wget2 -q --max-threads 20 -P "${domain}-pages" -i retrieved_url_list
  # 5. readability + to-org for each html-file
  parallel convert-html-file-to-clean-org ${domain-pages/*.html}
}

export -f convert-html-file-to-clean-org
# get-sitemaps "$1"
