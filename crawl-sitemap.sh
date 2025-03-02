#!/usr/bin/env bash

# recall cmds:

# declare myrand="$((RANDOM))-azure-business-continuity-center"; cd
# ~/org/stash/stash2/ && mkdir -p "$myrand" && cd "$myrand" && gauw
# $URL >
# currentstash-"$myrand" && parallel h2o :::: currentstash-"$myrand" && updatedb
# -l 0 -o ${HOME}/org/stash/plocate.db -U ${HOME}/org/stash

# declare myrand="$((RANDOM))-aws-ecs"; cd ~/org/stash/stash2/ && mkdir -p
# "$myrand" && cd "$myrand" && h2o-sitemap
# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/sitemap.xml &&
# updatedb -l 0 -o ${HOME}/org/stash/plocate.db -U ${HOME}/org/stash

# alias gauw="gau --threads 80 --fc 404 --mt text/html"

# * signals

function clean-htmls() {
  rm -rf /*.html
}

# * backend

function get-sitemap-urls-for-domain() {

  local url="${1}"

  local domain=${url/https:\/\//}
  echo "domain is $domain"
  local path="/tmp/${domain}-sitemap-crawler"
  mkdir -p "$path"
  echo "running 'gau' to find sitemap..."
  gau --threads 20 "${url}" | grep sitemap.xml
}

# TODO
function get-html-urls-for-domain() {
  local url="${1}"
  local domain=${url/https:\/\//}
  echo "domain is $domain"
  local path="/tmp/${domain}-sitemap-crawler"
  mkdir -p "$path"
  echo "running 'gau' to find sitemap..."
  gau --threads 50 --blacklist "/static/,404,pdk,sdk,images,png,jpg,gif,json,js,css,mp4,mp3,mpeg,sitemap,?ref" --fc 404,302 --mt text/html --subs
}

function retrieve-sitemaps-from-url-list() {
  local sitemap_urls_to_fetch="${1}"
  local prefix=$2

  # parallel
  wget2 -q -U "Firefox" --max-threads 20 -P "${prefix}-sitemaps" ${sitemap_urls_to_fetch[@]}
}

function get-urls-from-sitemap-list () {
  local sitemap_list="${1}"
  local -n result_array=$2
  # TODO: if csv
  echo "Grepping for URLs from site-map list.."
  result_array=$(xml_grep --cond 'loc' --text_only ${sitemap_list[@]})
}

function h2o () {
  trap clean-htmls SIGINT
  local url="${1}"
  local tag="${2}"
  if [[ -z $url ]]; then
    echo "No URL supplied."
    return
  fi
  # for parallelism,
  local random_int=$RANDOM
  # TODO: append string to title page as - STRING.org
  echo "wget: Fetching page..."
  wget -U "Firefox" "${url}" -O page.html-$random_int 2>>./wgeterrorout
  convert-html-file-to-clean-org page.html-$random_int "${tag}"
  rm -rf page.html-$random_int
}

function hh22oo () {
  pushd "${HOME}/org/stash" || exit
  h2o "${1}"
}

function hh22oo-sitemap () {
  pushd "${HOME}/org/stash/stash2" || exit
  h2o-sitemap "$(wl-paste)"
}

function h2o-sitemap () {
  local sitemap_url="${1}"
  local tag="${2}"
  local random_int=$RANDOM
  wget -U "Firefox" ${1} -O sitemap-$random_int.xml
  declare -a my_urls
  local my_urls
  get-urls-from-sitemap-list sitemap-$random_int.xml my_urls
  parallel h2o "${tag}" ::: ${my_urls[@]}
  rm -rf sitemap-$random_int.xml
  # mv *.org -t ../
  updatedb -l 0 -o ${HOME}/org/stash/plocate.db -U ${HOME}/org/stash/
}

function convert-html-file-to-clean-org () {
  local html_file="${1}"
  local tag="${2}"

  # TODO: err
  # 1. grab the title
  echo "xml_grep: Grepping title for ${html_file}"

  # TODO: test title grabbing for multiple e.g. Telemetry
  declare title
  local title="$(xml_grep --html 'title' --text_only $html_file 2>>./xmlgreperrorout | sort | head -1 | tr -d '\n')"
  echo "xml_grep: title found is ${title}"

  # no ’/’s in filenames. replace with ’\’
  # no ’|’s in filenames either. replace with ’-’
  # 2. some sanitizing

  # TODO: more sanitizing
  title=${title/\//\\}
  title=${title/\|/\-}

  # 3. append tag
  echo "appending tag ${tag} to title if existent"
  if [[ ${tag} != "" ]]; then
    title+="-${tag}"
  fi
  echo "Converting to org..."
  echo "Title: $title"
  set -x
  echo "URL: $url"
  echo "File: $html_file"
  set +x

  # make the org file
  echo -e "* ${title} \n" >"${title}.org"
  echo " " >>"${title}.org"
  # TODO: proper wrapping of org links (so they're not on multiple lines)
  # TODO: extract media and place as org
  echo "Pandoc: converting ${html_file} to ${title}.org"
  pandoc --quiet --sandbox=true "${html_file}" --from html --to org \
    --wrap=auto --columns=80 --toc=false \
    --strip-comments --tab-stop=2 --trace=false --shift-heading-level-by=1 1>>"${title}.org" 2>>./panerrorout
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
    echo "${item}" >retreived_url_list
  done
  wget2 -U "Firefox" -q --max-threads 20 -P "${domain}-pages" -i retrieved_url_list
  # 5. readability + to-org for each html-file
  parallel convert-html-file-to-clean-org ${domain-pages/*.html}
}

function update-stash-in-dir () {
  local dir="${1}"
  updatedb -l 0 -U "${dir}" -o "${dir}/plocate.db"

}
export -f convert-html-file-to-clean-org
export -f h2o
export -f hh22oo
export -f h2o-sitemap
export -f hh22oo-sitemap
alias update-my-stash="update-stash-in-dir $HOME/org/stash"
