#!/bin/sh

logger -t check_for_git_commits.sh -p local4.notice "touching ~ingress/signals/check_git ~ingress/signals/job_waiting"
echo touch ~ingress/signals/check_git ~ingress/signals/job_waiting | sudo su -fm ingress
logger -t check_for_git_commits.sh -p local4.notice "done touching, going away now"
