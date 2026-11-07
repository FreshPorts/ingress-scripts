#!/bin/sh
#
# Sourced, not run.  Source config.sh first.
#
# The last commit FreshPorts has processed, for each repo and branch.
#
# This is a return to where git-delta.sh started.  Commit hashes are from
# the git_proc_commit repo.
#
# The first version of git-delta.sh to remember where it got to (497dc9f,
# 2020-07-20) kept the latest commit in a file outside the repo:
# ${INGRESS_PORTS_DIR_BASE}/latest.freebsd-ports, and from b4e8088
# (2020-07-26) one latest.<dir> for each repo.
#
# b6f5027 (2021-06-28) replaced the files with a tag per branch in each
# repo, freshports/origin/main and so on, following the script Mathieu
# Arnold posted to freebsd-git on 2020-11-24, "Monitoring commits on all
# branches":
#
#   https://lists.freebsd.org/pipermail/freebsd-git/2020-November/000498.html
#
# The doubt at the time was that if we lose the repo, we lose our starting
# points:
#
#   https://news.freshports.org/2021/06/20/processing-commits-on-branches-with-git/
#
# The last mention of the files went in 50693bd (2023-01-02).
#
# That doubt is why it is back outside the repos: one file, with a line per
# repo and branch, so a repo can be thrown away and cloned again without
# losing our place.  See https://github.com/FreshPorts/freshports/issues/522
#
# One line per repo and branch:
#
#   ports:freshports/origin/main:67f02d5de925c31ed43cfd369a50295510637da1
#
# which is the format git-last-processed-tags.sh has always written, so the
# file it left behind is where this one starts from.
#
# git-delta.sh is the only writer.  Everything else reads.
#
# config.sh may set LATEST_COMMITS_FILE.
#

LATEST_COMMITS_FILE=${LATEST_COMMITS_FILE:-${INGRESS_BASEDIR:-/var/db/ingress}/latest_commits/latest_commits.txt}

#
# latest_commit_get repo refname
#
# e.g. latest_commit_get ports origin/main
#
# Prints the commit, and returns 0.  Prints nothing and returns 1 if the
# file is missing or has no line for that repo and branch.
#
latest_commit_get() {
	local repo refname

	repo=$1
	refname=$2

	[ -r "${LATEST_COMMITS_FILE}" ] || return 1

	awk -F: -v key="${repo}:freshports/${refname}" '
		$1 ":" $2 == key { commit = $3 }
		END { if (commit == "") exit 1; print commit }
	' "${LATEST_COMMITS_FILE}"
}

#
# latest_commit_check repo refname repodir
#
# TRANSITION ONLY: remove along with the tags, in the release after the one
# which moved to this file.
#
# Compares the file with the freshports/<refname> tag which git-delta.sh
# still writes.  They should always agree; if they do not, something other
# than git-delta.sh has moved one of them, and neither can be trusted.
#
# Missing from both counts as agreeing: a new branch.
#
# Returns 0 if they agree.  Otherwise prints both values and returns 1.
#
# safe.directory because compare-index-daily.sh runs as freshports and the
# repo belongs to ingress.
#
latest_commit_check() {
	local repo refname repodir from_file from_tag

	repo=$1
	refname=$2
	repodir=$3

	from_file=$(latest_commit_get ${repo} ${refname})
	from_tag=$(${GIT:-git} -c safe.directory=${repodir} -C ${repodir} \
		rev-parse -q --verify "freshports/${refname}^{}")

	[ "${from_file}" = "${from_tag}" ] && return 0

	echo "${repo} ${refname}: ${LATEST_COMMITS_FILE} has '${from_file}' but tag freshports/${refname} in ${repodir} has '${from_tag}'"
	return 1
}

#
# latest_commit_set repo refname commit
#
# e.g. latest_commit_set ports origin/main 67f02d5de925c31ed43cfd369a50295510637da1
#
# Replaces the line for that repo and branch, or adds one.  The new file is
# written next to the old one and moved over it, so a reader sees either
# the old file or the new one, never half of one.
#
# Returns non-zero, and leaves the file as it was, on any failure.
#
latest_commit_set() {
	local repo refname commit dir tmp

	repo=$1
	refname=$2
	commit=$3

	# a full hash, nothing else: anything shorter could later become ambiguous
	if ! echo "${commit}" | grep -qxE '[0-9a-f]{40}'
	then
		echo "latest_commit_set: '${commit}' is not a full commit hash" >&2
		return 1
	fi

	dir=$(dirname "${LATEST_COMMITS_FILE}")
	tmp=$(mktemp "${dir}/.latest_commits.XXXXXX") || return 1

	# every other line, unchanged
	if [ -f "${LATEST_COMMITS_FILE}" ]
	then
		if ! awk -F: -v key="${repo}:freshports/${refname}" \
			'$1 ":" $2 != key' "${LATEST_COMMITS_FILE}" > "${tmp}"
		then
			rm -f "${tmp}"
			return 1
		fi
	fi

	# mktemp makes it 0600; compare-index-daily.sh reads it as freshports
	echo "${repo}:freshports/${refname}:${commit}" >> "${tmp}" &&
		sort -o "${tmp}" "${tmp}" &&
		chmod 0644 "${tmp}" &&
		mv -f "${tmp}" "${LATEST_COMMITS_FILE}" && return 0

	rm -f "${tmp}"
	return 1
}
