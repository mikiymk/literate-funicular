/* $OpenBSD: main.c,v 1.34 2020/05/24 17:31:54 espie Exp $	 */
/* $NetBSD: main.c,v 1.5 1996/03/19 03:21:38 jtc Exp $	 */

/*
 * Copyright (c) 1989 The Regents of the University of California.
 * All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * Robert Paul Corbett.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#include <sys/types.h>
#include <fcntl.h>
#include "paths.h"
#include <stdlib.h>
// #include <unistd.h>
#include "defs.h"

#ifndef HAVE_PROGNAME
char *__progname;
#endif

char dflag;
char lflag;
char rflag;
char tflag;
char vflag;

char *symbol_prefix;
char *file_prefix = "y";

int lineno;
int outline;

int explicit_file_name;

char *code_file_name;
char *defines_file_name;
char *input_file_name = "";
char *output_file_name;
char *verbose_file_name;

FILE *action_file;	/* a temp file, used to save actions associated    */
					/* with rules until the parser is written	   */
FILE *code_file;	/* y.code.c (used when the -r option is specified) */
FILE *defines_file; /* y.tab.h					   */
FILE *input_file;	/* the input file				   */
FILE *output_file;	/* y.tab.c					   */
FILE *text_file;	/* a temp file, used to save text until all	   */
					/* symbols have been defined			   */
FILE *union_file;	/* a temp file, used to save the union		   */
					/* definition until all symbol have been	   */
					/* defined					   */
FILE *verbose_file; /* y.output					   */

int nitems;
int nrules;
int nsyms;
int ntokens;
int nvars;

int start_symbol;
char **symbol_name;
short *symbol_value;
short *symbol_prec;
char *symbol_assoc;

short *ritem;
short *rlhs;
short *rrhs;
short *rprec;
char *rassoc;
short **derives;
char *nullable;

void usage(void);
void getargs(int, char *[]);
void create_file_names(void);
void open_files(void);

// usage
//
// noreturn
// 標準エラー出力に使い方を表示してエラー終了する
void usage(void)
{
	fprintf(stderr, "usage: %s [-dlrtv] [-b file_prefix] [-o output_file] [-p symbol_prefix] file\n", __progname);
	exit(1);
}

// getargs
//
// 引数
// - `argc` - 引数の数
// - `argv` - 引数文字列の配列
//
// プログラムの引数を読み込んで、オプションに対応したグローバル変数を設定する
void getargs(int argc, char *argv[])
{
	// getoptの戻り値を受け取る変数
	int ch;

	while ((ch = getopt(argc, argv, "b:dlo:p:rtv")) != -1)
	{
		switch (ch)
		{
		case 'b':
			// -b file_prefix
			// ファイル接頭辞を設定する
			// デフォルトは"y"
			file_prefix = optarg;
			break;

		case 'd':
			// -d
			// ヘッダーファイルを作成します。
			dflag = 1;
			break;

		case 'l':
			// -l
			// todo
			lflag = 1;
			break;

		case 'o':
			// -o output_file
			// 出力ファイルのファイル名を設定する
			output_file_name = optarg;
			explicit_file_name = 1;
			break;

		case 'p':
			// -p symbol_prefix
			// 出力ファイルの中のシンボル名の接頭辞を設定する
			symbol_prefix = optarg;
			break;

		case 'r':
			// -r
			// コードファイルを出力ファイルと別で作成します。
			rflag = 1;
			break;

		case 't':
			// -t
			// todo
			tflag = 1;
			break;

		case 'v':
			// -v
			// verboseモードを設定する
			// 処理中の内容を詳しく出力する
			vflag = 1;
			break;

		default:
			// 上記以外のオプションを受け取った場合、使い方を表示して終了
			usage();
		}
	}

	// 上のオプション解析で解析済みの引数をスキップする
	argc -= optind;
	argv += optind;

	// ただ一つの引数でない場合は使い方を表示して終了
	if (argc != 1)
		usage();
	// 引数が"-"なら標準入力を入力ファイルとする
	if (strcmp(*argv, "-") == 0)
		input_file = stdin;
	// それ以外の場合、入力ファイルを受け取る
	else
		input_file_name = *argv;
}

void *
allocate(size_t n)
{
	void *v;

	v = NULL;
	if (n)
	{
		v = calloc(1, n);
		if (!v)
			no_space();
	}
	return (v);
}

/**
 * create_file_names
 *
 * ファイル名を作成します
 */
void create_file_names(void)
{
	// -oオプションがなかった場合、output_fileは未設定の状態です。
	if (output_file_name == NULL)
	{
		// {prefix}.tab.cになります。
		if (asprintf(&output_file_name, "%s%s", file_prefix, OUTPUT_SUFFIX) == -1)
			no_space();
	}
	// -rオプション
	if (rflag)
	{
		// {prefix}.code.cになります。
		if (asprintf(&code_file_name, "%s%s", file_prefix, CODE_SUFFIX) == -1)
			no_space();
	}
	else
		code_file_name = output_file_name;

	// -dオプション
	if (dflag)
	{
		// -oオプションがある場合
		if (explicit_file_name)
		{
			char *suffix;

			// 出力ファイル名と同じ名前の.hファイル名を作成します

			defines_file_name = strdup(output_file_name);
			if (defines_file_name == 0)
				no_space();

			/* does the output_file_name have a known suffix */
			// 拡張子が以下のうちにあるなら
			if ((suffix = strrchr(output_file_name, '.')) != 0 &&
				(!strcmp(suffix, ".c") ||	/* good, old-fashioned C */
				 !strcmp(suffix, ".C") ||	/* C++, or C on Windows */
				 !strcmp(suffix, ".cc") ||	/* C++ */
				 !strcmp(suffix, ".cxx") || /* C++ */
				 !strcmp(suffix, ".cpp")))
			{ /* C++ (Windows) */
				// そこの部分を.hで終わらせる
				strncpy(defines_file_name, output_file_name,
						suffix - output_file_name + 1);
				defines_file_name[suffix - output_file_name + 1] = 'h';
				defines_file_name[suffix - output_file_name + 2] = '\0';
			}
			// それ以外の場合
			else
			{
				// エラー出力して、ヘッダーファイルを使用しないで続ける
				fprintf(stderr, "%s: suffix of output file name %s"
								" not recognized, no -d file generated.\n",
						__progname, output_file_name);
				dflag = 0;
				free(defines_file_name);
				defines_file_name = 0;
			}
		}
		// -oオプションがない場合
		else
		{
			// {prefix}.tab.hになります。
			if (asprintf(&defines_file_name, "%s%s", file_prefix,
						 DEFINES_SUFFIX) == -1)
				no_space();
		}
	}

	// -vオプション
	if (vflag)
	{
		// {prefix}.outputになります。
		if (asprintf(&verbose_file_name, "%s%s", file_prefix,
					 VERBOSE_SUFFIX) == -1)
			no_space();
	}
}

FILE *create_temp(void)
{
	FILE *f;

	f = tmpfile();
	if (f == NULL)
		tempfile_error();
	return f;
}

// open_files
//
// 必要なファイルを開く
void open_files(void)
{
	create_file_names();

	if (input_file == NULL)
	{
		input_file = fopen(input_file_name, "r");
		if (input_file == NULL)
			open_error(input_file_name);
	}
	action_file = create_temp();

	text_file = create_temp();

	if (vflag)
	{
		verbose_file = fopen(verbose_file_name, "w");
		if (verbose_file == NULL)
			open_error(verbose_file_name);
	}
	if (dflag)
	{
		defines_file = fopen(defines_file_name, "w");
		if (defines_file == NULL)
			open_write_error(defines_file_name);
		union_file = create_temp();
	}
	output_file = fopen(output_file_name, "w");
	if (output_file == NULL)
		open_error(output_file_name);

	if (rflag)
	{
		code_file = fopen(code_file_name, "w");
		if (code_file == NULL)
			open_error(code_file_name);
	}
	else
		code_file = output_file;
}

// # main関数
//
// プログラムで最初に実行される関数
int main(int argc, char *argv[])
{
	// __prognameはプログラム名
	// なかったら用意する
#ifndef HAVE_PROGNAME
	__progname = argv[0];
#endif

#ifdef HAVE_PLEDGE
	// pledgeは機能を有効にする関数
	// stdio = 標準入出力
	// rpath = 書き込み用ファイルシステム
	// wpath = 読み込み用ファイルシステム
	// cpath = ファイル・ディレクトリ作成用ファイルシステム
	if (pledge("stdio rpath wpath cpath", NULL) == -1)
		fatal("pledge: invalid arguments");
#endif

	getargs(argc, argv);
	open_files();
	reader();
	lr0();
	lalr();
	make_parser();
	verbose();
	output();
	return (0);
}
