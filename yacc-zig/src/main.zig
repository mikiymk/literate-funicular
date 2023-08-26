const std = @import("std");

// #include <sys/types.h>
// #include <fcntl.h>
// #include "paths.h"
// #include <stdlib.h>
// // #include <unistd.h>
// #include "defs.h"

// #ifndef HAVE_PROGNAME
// char *__progname;
// #endif

// char dflag;
// char lflag;
// char rflag;
// char tflag;
// char vflag;

// char *symbol_prefix;
// char *file_prefix = "y";

// int lineno;
// int outline;

// int explicit_file_name;

// char *code_file_name;
// char *defines_file_name;
// char *input_file_name = "";
// char *output_file_name;
// char *verbose_file_name;

// FILE *action_file;	/* a temp file, used to save actions associated    */
// 			/* with rules until the parser is written	   */
// FILE *code_file;	/* y.code.c (used when the -r option is specified) */
// FILE *defines_file;	/* y.tab.h					   */
// FILE *input_file;	/* the input file				   */
// FILE *output_file;	/* y.tab.c					   */
// FILE *text_file;	/* a temp file, used to save text until all	   */
// 			/* symbols have been defined			   */
// FILE *union_file;	/* a temp file, used to save the union		   */
// 			/* definition until all symbol have been	   */
// 			/* defined					   */
// FILE *verbose_file;	/* y.output					   */

// int nitems;
// int nrules;
// int nsyms;
// int ntokens;
// int nvars;

// int start_symbol;
// char **symbol_name;
// short *symbol_value;
// short *symbol_prec;
// char *symbol_assoc;

// short *ritem;
// short *rlhs;
// short *rrhs;
// short *rprec;
// char *rassoc;
// short **derives;
// char *nullable;

// void usage(void);
// void getargs(int, char *[]);
// void create_file_names(void);
// void open_files(void);

// void
// usage(void)
// {
// 	fprintf(stderr, "usage: %s [-dlrtv] [-b file_prefix] [-o output_file] [-p symbol_prefix] file\n", __progname);
// 	exit(1);
// }

// void
// getargs(int argc, char *argv[])
// {
// 	int ch;

// 	while ((ch = getopt(argc, argv, "b:dlo:p:rtv")) != -1) {
// 		switch (ch) {
// 		case 'b':
// 			file_prefix = optarg;
// 			break;

// 		case 'd':
// 			dflag = 1;
// 			break;

// 		case 'l':
// 			lflag = 1;
// 			break;

// 		case 'o':
// 			output_file_name = optarg;
// 			explicit_file_name = 1;
// 			break;

// 		case 'p':
// 			symbol_prefix = optarg;
// 			break;

// 		case 'r':
// 			rflag = 1;
// 			break;

// 		case 't':
// 			tflag = 1;
// 			break;

// 		case 'v':
// 			vflag = 1;
// 			break;

// 		default:
// 			usage();
// 		}
// 	}
// 	argc -= optind;
// 	argv += optind;

// 	if (argc != 1)
// 		usage();
// 	if (strcmp(*argv, "-") == 0)
// 		input_file = stdin;
// 	else
// 		input_file_name = *argv;
// }

// void *
// allocate(size_t n)
// {
// 	void *v;

// 	v = NULL;
// 	if (n) {
// 		v = calloc(1, n);
// 		if (!v)
// 			no_space();
// 	}
// 	return (v);
// }

// void
// create_file_names(void)
// {
// 	if (output_file_name == NULL) {
// 		if (asprintf(&output_file_name, "%s%s", file_prefix, OUTPUT_SUFFIX)
// 		    == -1)
// 			no_space();
// 	}
// 	if (rflag) {
// 		if (asprintf(&code_file_name, "%s%s", file_prefix, CODE_SUFFIX) == -1)
// 			no_space();
// 	} else
// 		code_file_name = output_file_name;

// 	if (dflag) {
// 		if (explicit_file_name) {
// 			char *suffix;

// 			defines_file_name = strdup(output_file_name);
// 			if (defines_file_name == 0)
// 				no_space();

// 			/* does the output_file_name have a known suffix */
// 			if ((suffix = strrchr(output_file_name, '.')) != 0 &&
// 			    (!strcmp(suffix, ".c") ||	/* good, old-fashioned C */
// 			     !strcmp(suffix, ".C") ||	/* C++, or C on Windows */
// 			     !strcmp(suffix, ".cc") ||	/* C++ */
// 			     !strcmp(suffix, ".cxx") ||	/* C++ */
// 			     !strcmp(suffix, ".cpp"))) {/* C++ (Windows) */
// 				strncpy(defines_file_name, output_file_name,
// 					suffix - output_file_name + 1);
// 				defines_file_name[suffix - output_file_name + 1] = 'h';
// 				defines_file_name[suffix - output_file_name + 2] = '\0';
// 			} else {
// 				fprintf(stderr, "%s: suffix of output file name %s"
// 				 " not recognized, no -d file generated.\n",
// 					__progname, output_file_name);
// 				dflag = 0;
// 				free(defines_file_name);
// 				defines_file_name = 0;
// 			}
// 		} else {
// 			if (asprintf(&defines_file_name, "%s%s", file_prefix,
// 				     DEFINES_SUFFIX) == -1)
// 				no_space();
// 		}
// 	}
// 	if (vflag) {
// 		if (asprintf(&verbose_file_name, "%s%s", file_prefix,
// 			     VERBOSE_SUFFIX) == -1)
// 			no_space();
// 	}
// }

// FILE *
// create_temp(void)
// {
// 	FILE *f;

// 	f = tmpfile();
// 	if (f == NULL)
// 		tempfile_error();
// 	return f;
// }

// void
// open_files(void)
// {
// 	create_file_names();

// 	if (input_file == NULL) {
// 		input_file = fopen(input_file_name, "r");
// 		if (input_file == NULL)
// 			open_error(input_file_name);
// 	}
// 	action_file = create_temp();

// 	text_file = create_temp();

// 	if (vflag) {
// 		verbose_file = fopen(verbose_file_name, "w");
// 		if (verbose_file == NULL)
// 			open_error(verbose_file_name);
// 	}
// 	if (dflag) {
// 		defines_file = fopen(defines_file_name, "w");
// 		if (defines_file == NULL)
// 			open_write_error(defines_file_name);
// 		union_file = create_temp();
// 	}
// 	output_file = fopen(output_file_name, "w");
// 	if (output_file == NULL)
// 		open_error(output_file_name);

// 	if (rflag) {
// 		code_file = fopen(code_file_name, "w");
// 		if (code_file == NULL)
// 			open_error(code_file_name);
// 	} else
// 		code_file = output_file;
// }

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var argv: []const []const u8 = try std.process.argsAlloc(allocator);
    var argc: usize = argv.len;
    _ = argc;

    // getargs(argc, argv);
    // open_files();
    // reader();
    // lr0();
    // lalr();
    // make_parser();
    // verbose();
    // output();
    return;
}
