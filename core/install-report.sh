#!/bin/bash
# shellcheck disable=SC1091,SC2312
source /usr/local/lib/marshall_installer
printf "Executing: %b%s%b\n" "${COLOUR_SUCCESS}" "Install Report" "${COLOUR_RESET}"

PHP_VERSION=$(/usr/bin/php --version | head -n 1 | cut -f2 -d' ' | cut -f1 -d'-')
COMPOSER_VERSION=$(/usr/local/bin/composer --version | cut -f3 -d' ')
GIT_VERSION=$(git --version | sed 's|git version ||')
PROJECT_CODE_SIZE=$(du -cBM /app | grep total | cut -f1)
PROJECT_CODE_SIZE_BYTES=$(du -c /app | grep total | cut -f1)
PHP_MODULES=$(/usr/bin/php -m)
MAX_CODE_SIZE_BYTES=100000000
MODULES_COLUMNS=6

[[ ${PROJECT_CODE_SIZE_BYTES} -gt ${MAX_CODE_SIZE_BYTES} ]] && COLOUR_CODE_SIZE="${COLOUR_FAIL}" || COLOUR_CODE_SIZE="${COLOUR_SUCCESS}"

MODULES=("SimpleXML" "dom" "mcrypt" "sodium" "Reflection" "xml" "xsl" "Xdebug" "PDO" "pdo_mysql" "pdo_pgsql" "pdo_sqlite" "mysqlnd" "mysqli" "pgsql" "sqlite3" "tokenizer" "bz2" "zip" "zlib" "apcu" "redis" "mongodb" "memcached" "gd" "exif" "imap" "bcmath" "intl" "json" "ldap" "mbstring" "curl" "soap")
echo -e "Ubuntu Version installed:   ${COLOUR_BRIGHT_BLUE}${UBUNTU_VERSION}${COLOUR_RESET}"
echo -e "PHP Version installed:      ${COLOUR_BRIGHT_BLUE}${PHP_VERSION}${COLOUR_RESET}"
echo -e "Composer Version installed: ${COLOUR_BRIGHT_BLUE}${COMPOSER_VERSION}${COLOUR_RESET}"
echo -e "Git Version installed:      ${COLOUR_BRIGHT_BLUE}${GIT_VERSION}${COLOUR_RESET}"
echo -e "Application Size:           ${COLOUR_CODE_SIZE}${PROJECT_CODE_SIZE}${COLOUR_RESET}"
echo -e "PHP Modules installed:"
i=1
for module in "${MODULES[@]}"; do
	(
		[[ ${PHP_MODULES} =~ ${module} ]] &&
			printf "%b%s%b %-14s " "${COLOUR_SUCCESS}" "✓" "${COLOUR_RESET}" "${module}" ||
			printf "%b%s%b %-14s " "${COLOUR_FAIL}" "✕" "${COLOUR_RESET}" "${module}"
	)
	if ! ((i % MODULES_COLUMNS)); then
		echo ""
	fi
	i=$((i + 1))
done
echo

# @todo This bombs out if it can't read from a restricted repo. Revise later.
#if [ -f /app/composer.json ]; then
#    if [ -f /app/composer.lock ]; then
#        echo -e "Outdated ${COLOUR_FAIL}Composer${COLOUR_NONE} packages:"
#        /usr/local/bin/composer outdated
#    fi
#fi
