#!/bin/bash -eux

cd $(readlink -m $0/../..)
test -f setup.py

teardown() {
    exit_code=$?
    # rpmbuild requires files to be owned by running uid
    sudo chown --recursive $(id -u):$(id -g) rpm/

    trap - EXIT INT TERM

    # If not on CI and we are docker entrypoint (PID 1), let's wait forever on
    # error. This allows user to enter the container and debug after a build
    # failure.
    if [ -z "${CI-}" -a $$ = 1 -a $exit_code -gt 0 ] ; then
        tail -f /dev/null
    fi
}

trap teardown EXIT INT TERM

sudo yum-builddep -y rpm/temboard.spec

# Building sources in rpm/
python setup.py sdist --dist-dir rpm/
! diff -u \
  --label ../share/temboard.conf share/temboard.conf \
  rpm/temboard.rpm.conf > rpm/temboard.conf.patch

# rpmbuild requires files to be owned by running uid
sudo chown --recursive $(id -u):$(id -g) rpm/

rpmbuild \
    --define "pkgversion $(python setup.py --version)" \
    --define "_topdir ${PWD}/dist/rpm" \
    --define "_sourcedir ${PWD}/rpm" \
    -ba rpm/temboard.spec
