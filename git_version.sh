#!/bin/sh
#
# Generate some basic versioning information which can be piped to a header.
#
# Copyright (c) 2006-2007 Luc Verhaegen <libv@skynet.be>
# Copyright (C) 2007-2008 Hans Ulrich Niedermann <hun@n-dimensional.de>
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
# THE COPYRIGHT HOLDER(S) OR AUTHOR(S) BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#
# This script is based on the one written for xf86-video-unichrome by
# Luc Verhaegen, but was rewritten almost completely by Hans Ulrich
# Niedermann. The script contains a few bug fixes from Egbert Eich,
# Matthias Hopf, Joerg Sonnenberger, and possibly others.
#
# The author thanks the nice people on #git for the assistance.
#
# Simple testing of this script:
#   /sbin/busybox sh git_version.sh --example > moo.c \
#     && gcc -Wall -Wextra -Wno-unused -o moo moo.c \
#     && ./moo
#   (bash should also do)
#
# For how to hook this up to your automake- and/or imake-based build
# system, best take a look at how the RadeonHD.am and/or RadeonHD.tmpl
# work in the xf86-video-radeonhd build system. For non-recursive make,
# you can probably make things a little bit simpler.
#
# Requires git >= 1.3.0 for the 'git foo' (with space) syntax,
#      and git >= 1.4   for some specific commands.

# Help messages
USAGE="[<option>...]"
LONG_USAGE="\
Options:
  -h, --help             Print this help message.

  -k, --keep-if-no-repo  Keep old output file if no git repo found.
  -o, --output FILENAME  Set output file name.
  -q, --quiet            Quiet output.
  -s, --srcdir DIRNAME   Set source tree dir name.
  -x, --example          Print complete example program."

# The caller may have set these for us
SED="${SED-sed}"
GIT="${GIT-git}"

# Initialize
working_dir=`pwd`

# Who am I?
self=`basename "$0"`

# Defaults
ifndef_symbol="GIT_VERSION_H"
outfile="-"
print_example=false
keep_if_no_repo=no
quiet=false
srcdir=`pwd`

# Parse command line parameter, affecting defaults
while [ "x$1" != "x" ]
do
    case "$1" in
        -x|--example)
            print_example=:
            ;;
        -o|--output)
            if shift; then
                outfile="$1"
                if [ "x$outfile" = "x-" ]; then
                    : # keep default ifndef_symbol
                else
                    ifndef_symbol=`basename "$outfile" | $SED 's|\.|_|g; s|[^A-Za-z0-9_]||g' | tr a-z A-Z`
                fi
            else
                echo "$self: Fatal: \"$1\" option requires parameter." >&2
                exit 1
            fi
            ;;
        -q|--quiet)
            quiet=:
            ;;
        -h|--help)
            echo "Usage: ${self} $USAGE"
            [ -n "$LONG_USAGE" ] && echo "$LONG_USAGE"
            exit
            ;;
        -k|--keep-if-no-repo)
            keep_if_no_repo=yes
            ;;
	-s|--srcdir)
	    if shift; then
		if test -d "$1"; then
		    srcdir="$1"
		else
		    echo "$self: Fatal: \"$1\" not a directory." >&2
		    exit 1
		fi
	    else
		echo "$self: Fatal: \"$1\" option requires directory parameter." >&2
		exit 1
	    fi
	    ;;
        *)
            echo "$self: Fatal: Invalid command line paramenter: \"$1\"" >&2
            exit 1
            ;;
    esac
    shift
done

# If not printing to stdout, redirect stdout to output file?
rename_new_output=false
if [ "x$outfile" = "x-" ]
then
    : # keep using stdout
else
    exec 1> "${outfile}.new"
fi

# Done with creating output files, so we can change to source dir
abs_srcdir=`cd "$srcdir" && pwd`
cd "$srcdir"

# Write program header
cat<<EOF
/*
 * Basic versioning gathered from the git repository.
 * Automatically generated by $0.
 */

#ifndef ${ifndef_symbol}
#define ${ifndef_symbol} 1

/* whether this is a dist tarball or not */
#undef GIT_IS_DIST

EOF

# Detect git tool (should work with old and new git versions)
git_found=yes
if [ "x$GIT" = "xgit" ] && [ "x`which $GIT 2>/dev/null`" = "x" ]; then
    git_found="'$GIT' not found"
    break
fi
# If git_found=yes, we can now use $() substitutions (as git does). Hooray!

# Determine git specific defines
unset git_errors ||:
if [ "x$git_found" = "xyes" ]; then
    git_version=`$GIT --version`
    if [ "x$git_version" = "x" ]; then
        git_errors="${git_errors+${git_errors}; }error running '$GIT --version'"
    fi
fi

git_repo=no
# "git-rev-parse --git-dir" since git-0.99.7
git_repo_dir="$($GIT rev-parse --git-dir 2> /dev/null || true)"
if [ "x$git_repo_dir" != "x" ]; then
    git_repo=yes
    if [ "x$git_found" = "xyes" ]; then
        # git-1.4 and probably earlier understand "git-rev-parse HEAD"
        git_shaid=`$GIT rev-parse HEAD | $SED -n 's/^\(.\{8\}\).*/\1/p'`
        if [ "x$git_shaid" = "x" ]; then
            git_errors="${git_errors+${git_errors}; }error running '$GIT rev-parse HEAD'"
        fi
        # git-1.4 and probably earlier understand "git-symbolic-ref HEAD"
        git_branch=`$GIT symbolic-ref HEAD | $SED -n 's|^refs/heads/||p'`
        if [ "x$git_branch" = "x" ]; then
            # This happens, is OK, and "(no branch)" is what "git branch" prints.
            git_branch="(no branch)"
        fi
        git_dirty=yes
        # git-1.4 does not understand "git-diff-files --quiet"
        # git-1.4 does not understand "git-diff-index --cached --quiet HEAD"
        if [ "x$($GIT diff-files)" = "x" ] && [ "x$($GIT diff-index --cached HEAD)" = "x" ]; then
            git_dirty=no
        fi

	# dkorth changes [2013/07/21 10:18 AM EDT]
	# Get the current git description.
	# (String will be empty if no description is available or if git is too old.)
	git_describe=`$GIT describe --abbrev=8`
    fi
fi

# Write git specific defines
if [ "x$git_errors" = "x" ]; then
    echo "/* No errors occured while running git */"
    echo "#undef GIT_ERRORS"
else
    echo "/* Some errors occured while running git */"
    echo "#define GIT_ERRORS \"${git_errors}\""
fi
echo ""

if [ "x$git_found" = "xyes" ]; then
    echo "/* git utilities found */"
    echo "#undef GIT_NOT_FOUND"
    echo "#define GIT_VERSION \"${git_version}\""
else
    echo "/* git utilities not found */"
    echo "#define GIT_NOT_FOUND \"${git_found}\""
    echo "#undef GIT_VERSION"
fi
echo ""

if :; then # debug output
cat<<EOF
/* The following helps debug why we sometimes do not find ".git/":
 * abs_repo_dir="${abs_repo_dir}" (should be "/path/to/.git")
 * abs_srcdir="${abs_srcdir}" (absolute top source dir "/path/to")
 * git_repo_dir="${git_repo_dir}" (usually ".git" or "/path/to/.git")
 * PWD="${PWD}"
 * srcdir="${srcdir}"
 * working_dir="${working_dir}"
 */

EOF
fi

if [ "x$git_repo" = "xno" ]; then
    echo "/* No git repo found, probably building from dist tarball */"
    echo "#undef GIT_REPO"
else
    echo "/* git repo found */"
    echo "#define GIT_REPO 1"
    echo ""
    if [ "x$git_found" = "xyes" ]; then
        echo "/* Git SHA ID of last commit */"
        echo "#define GIT_SHAID \"${git_shaid}\""
        echo ""

        echo "/* Branch this tree is on */"
        echo "#define GIT_BRANCH \"$git_branch\""
        echo ""

        if [ "x$git_describe" = "x" ]; then
            echo "/* git-describe: no description available (no tag?) */"
            echo "#undef GIT_DESCRIBE"
        else
            echo "/* git-describe (e.g. tag, number of commits since tag) */"
            echo "#define GIT_DESCRIBE \"${git_describe}\""
        fi
        echo ""

        # Any uncommitted changes we should know about?
        # Or technically: Are the working tree or index dirty?
        if [ "x$git_dirty" = "xno" ]; then
            echo "/* SHA-ID uniquely defines the state of this code */"
            echo "#undef GIT_DIRTY"
        else
            echo "/* Local changes might be breaking things */"
            echo "#define GIT_DIRTY 1"
        fi
    fi
fi

# Define a few immediately useful message strings
cat<<EOF

/* Define GIT_MESSAGE such that
 *    printf("%s: built from %s", argv[0], GIT_MESSAGE);
 * forms a proper sentence.
 */

#ifdef GIT_DIRTY
# define GIT_DIRTY_MSG " + changes"
#else /* !GIT_DIRTY */
# define GIT_DIRTY_MSG ""
#endif /* GIT_DIRTY */

#ifdef GIT_ERRORS
# define GIT_ERROR_MSG " with error: " GIT_ERRORS
#else /* !GIT_ERRORS */
# define GIT_ERROR_MSG ""
#endif /* GIT_ERRORS */

#ifdef GIT_IS_DIST
# define GIT_DIST_MSG "dist of "
#else /* !GIT_IS_DIST */
# define GIT_DIST_MSG ""
#endif /* GIT_IS_DIST */

#ifdef GIT_REPO
# ifdef GIT_NOT_FOUND
#  define GIT_MESSAGE GIT_DIST_MSG "git sources without git: " GIT_NOT_FOUND
# else /* !GIT_NOT_FOUND */
#  define GIT_MESSAGE \\
       GIT_DIST_MSG \\
       "git branch " GIT_BRANCH ", " \\
       "commit " GIT_SHAID GIT_DIRTY_MSG \\
       GIT_ERROR_MSG
# endif /* GIT_NOT_FOUND */
#else /* !GIT_REPO */
# define GIT_MESSAGE GIT_DIST_MSG "non-git sources" GIT_ERROR_MSG
#endif /* GIT_REPO */

#endif /* ${ifndef_symbol} */
EOF

# Example program
if "$print_example"
then
    cat<<EOF

/* example program demonstrating the use of git_version.sh output */
#include <stdio.h>
#include <string.h>

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

int main(int argc, char *argv[])
{
    const char *const idx = strrchr(argv[0], '/');
    const char *const prog = (idx)?(idx+1):(argv[0]);
#ifdef PACKAGE_VERSION
    printf("%s: version %s, built from %s\n", prog, PACKAGE_VERSION, GIT_MESSAGE);
#elif defined(GIT_MESSAGE)
    printf("%s: built from %s\n", prog, GIT_MESSAGE);
#endif
    return 0;
}
EOF
fi

# Change back to working dir for the remaining output file manipulations.
cd "$working_dir"

# If necessary, overwrite outdated output file with new one
if [ "x$outfile" != "x-" ]
then
    if [ -f "$outfile" ]; then
        if [ "x$keep_if_no_repo" = "xyes" ] && [ "x$git_repo" = "xno" ]; then
            "$quiet" || echo "$self: Not a git repo, keeping existing $outfile" >&2
            rm -f "$outfile.new"
        elif cmp "$outfile" "$outfile.new" > /dev/null; then
            "$quiet" || echo "$self: Output is unchanged, keeping $outfile" >&2
            rm -f "$outfile.new"
        else
            echo "$self: Output has changed, updating $outfile" >&2
            mv -f "$outfile.new" "$outfile"
        fi
    else
        echo "$self: Output is new file, creating $outfile" >&2
        mv -f "$outfile.new" "$outfile"
    fi
fi

# THE END.
