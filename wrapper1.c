/* A wrapper for ikiwiki, can be safely made suid. */
#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <sys/file.h>

// $#envsave = 14

extern char **environ;
char *newenviron[14+7];
int i=0;

void addenv(char *var, char *val) {
	char *s=malloc(strlen(var)+1+strlen(val)+1);
	if (!s)
		perror("malloc");
	sprintf(s, "%s=%s", var, val);
	newenviron[i++]=s;
}

int main (int argc, char **argv) {
	int lockfd=-1;
	char *s;

// $check_commit_hook
// @wrapper_hooks
	if ((s=getenv("REMOTE_ADDR")))
		addenv("REMOTE_ADDR", s);
	if ((s=getenv("QUERY_STRING")))
		addenv("QUERY_STRING", s);
	if ((s=getenv("REQUEST_METHOD")))
		addenv("REQUEST_METHOD", s);
	if ((s=getenv("REQUEST_URI")))
		addenv("REQUEST_URI", s);
	if ((s=getenv("CONTENT_TYPE")))
		addenv("CONTENT_TYPE", s);
	if ((s=getenv("CONTENT_LENGTH")))
		addenv("CONTENT_LENGTH", s);
	if ((s=getenv("GATEWAY_INTERFACE")))
		addenv("GATEWAY_INTERFACE", s);
	if ((s=getenv("HTTP_COOKIE")))
		addenv("HTTP_COOKIE", s);
	if ((s=getenv("REMOTE_USER")))
		addenv("REMOTE_USER", s);
	if ((s=getenv("HTTPS")))
		addenv("HTTPS", s);
	if ((s=getenv("REDIRECT_STATUS")))
		addenv("REDIRECT_STATUS", s);
	if ((s=getenv("HTTP_HOST")))
		addenv("HTTP_HOST", s);
	if ((s=getenv("SERVER_PORT")))
		addenv("SERVER_PORT", s);
	if ((s=getenv("HTTPS")))
		addenv("HTTPS", s);
	if ((s=getenv("REDIRECT_URL")))
		addenv("REDIRECT_URL", s);

	newenviron[i++]="HOME=$ENV{HOME}";
	newenviron[i++]="PATH=$ENV{PATH}";
//	newenviron[i++]="WRAPPED_OPTIONS=$configstring";

	newenviron[i]=NULL;
	environ=newenviron;

	if (setregid(getegid(), -1) != 0 &&
	    setregid(getegid(), -1) != 0) {
		perror("failed to drop real gid");
		exit(1);
	}
	if (setreuid(geteuid(), -1) != 0 &&
	    setreuid(geteuid(), -1) != 0) {
		perror("failed to drop real uid");
		exit(1);
	}

// $pre_exec

	execl("/var/www/bin/mwiki.old", "/var/www/bin/mwiki.old", NULL);
	perror("exec /var/www/bin/mwiki.old");
	exit(1);
}
