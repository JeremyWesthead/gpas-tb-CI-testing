# To Do
Due to the limitations of Github's CI runners (5h timeout, storage limits etc), this will never successfully run on this.

Therefore in order for this to ever be used, a cronjob could be utilised to automatically run this workflow at regular intervals and complain in cases which fail.
This should be done via a server or VM which is consistently running, using the cron `00 17 * * 5` to run every Friday at 17:00. All this needs to do is run the `test.sh` script in this directory