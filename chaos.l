%{
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#if !defined(_WIN32) && !defined(_WIN64) && !defined(__CYGWIN__)
#include <readline/readline.h>
#include <readline/history.h>
#endif
#include "utilities/language.h"
#include "utilities/injector.h"
#if !defined(_WIN32) && !defined(_WIN64) && !defined(__CYGWIN__)
#include "utilities/shell.h"
#endif
#include "loop.h"

#define YY_DECL int yylex()

extern void recordToken(char *token, int length);
extern int oerrno;
extern void yyerror(const char* s);
#define YY_FATAL_ERROR(msg) yy_fatal_error( msg )

#include "chaos.tab.h"

enum Phase phase = INIT_PREPARSE;
unsigned short module_parsing = 0;

void injectCode(char *code, enum Phase phase_arg) {
    phase = phase_arg;
    inject_mode = true;

    YY_BUFFER_STATE old_buffer = YY_CURRENT_BUFFER;
    YY_BUFFER_STATE new_buffer = yy_scan_string(code);
    yy_switch_to_buffer(new_buffer);
    int ret = yyparse();
    yy_delete_buffer(new_buffer);
    yy_switch_to_buffer(old_buffer);

    inject_mode = false;
}

void yyrestart_interactive() {
    if (!YY_CURRENT_BUFFER){
        yyensure_buffer_stack();
		YY_CURRENT_BUFFER_LVALUE = yy_create_buffer(yyin, YY_BUF_SIZE);
	}

	yy_init_buffer(YY_CURRENT_BUFFER, yyin);
    YY_CURRENT_BUFFER_LVALUE->yy_is_interactive = true;
}

void flushLexer() {
    yy_flush_buffer(YY_CURRENT_BUFFER);
}

void parseTheModuleContent(char *module_path) {
    char *code = fileGetContents(module_path);

    if (code != NULL) {
        module_parsing++;
        injectCode(code, INIT_PREPARSE);
        module_parsing--;
        free(code);

        if (is_interactive) {
            phase = PROGRAM;
        }
    } else {
        append_to_array_without_malloc(&free_string_stack, module_path);
        throw_error(E_MODULE_IS_EMPTY_OR_NOT_EXISTS_ON_PATH, module_path);
    }
}

#define YY_SKIP_YYWRAP 1
int yywrap() { if (phase == PREPARSE && module_parsing == 0) { phase = INIT_PROGRAM; rewind(yyin); } return 1; }

#if !defined(_WIN32) && !defined(_WIN64) && !defined(__CYGWIN__)
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) result = custom_input(buf, result, max_size);

static int custom_input(char *buf, int result, int max_size) {
    if ( YY_CURRENT_BUFFER_LVALUE->yy_is_interactive ) {
        return shell_readline(buf);
    } else {
        errno = 0;
        while ( (result = (int) fread(buf, 1, (yy_size_t) max_size, yyin)) == 0 && ferror(yyin)) {
            if( errno != EINTR) {
                YY_FATAL_ERROR( "input in flex scanner failed" );
                break;
            }
            errno = 0;
            clearerr(yyin);
        }
        return result;
    }
}
#endif
%}

%x COMMENT

%%

%{

switch (phase)
{
    case INIT_PREPARSE:
        yylineno = reset_line_no_to;
        phase = PREPARSE;
        return START_PREPARSE;
        break;
    case INIT_PROGRAM:
        yylineno = reset_line_no_to;
        phase = PROGRAM;
        return START_PROGRAM;
        break;
    default:
        break;
}

%}

[ \t]                           {recordToken(strdup(yytext), yyleng);}; // ignore all whitespace
[0-9]+\.[0-9]+                  {recordToken(strdup(yytext), yyleng); yylval.fval = atof(yytext); if (isStreamOpen()) return T_FLOAT;}
[0-9]+                          {recordToken(strdup(yytext), yyleng); yylval.ival = atoi(yytext); if (isStreamOpen()) { return T_INT; } else { return T_TIMES_DO_INT; }}
\n                              {recordToken(strdup(yytext), yyleng); yylineno++; return T_NEWLINE;}
"="                             {recordToken(strdup(yytext), yyleng); if (isStreamOpen()) return T_EQUAL;}
"+"                             {recordToken(strdup(yytext), yyleng); if (isStreamOpen()) return T_PLUS;}
"-"                             {recordToken(strdup(yytext), yyleng); if (isStreamOpen()) return T_MINUS;}
"*"                             {recordToken(strdup(yytext), yyleng); if (isStreamOpen()) return T_MULTIPLY;}
"/"                             {recordToken(strdup(yytext), yyleng); if (isStreamOpen()) return T_DIVIDE;}
"\\"                            {recordToken(strdup(yytext), yyleng); if (isStreamOpen()) return T_BACKSLASH;}
"("                             {recordToken(strdup(yytext), yyleng); if (isStreamOpen()) return T_LEFT;}
")"                             {recordToken(strdup(yytext), yyleng); if (isStreamOpen()) return T_RIGHT;}
"["                             {recordToken(strdup(yytext), yyleng); if (isStreamOpen()) return T_LEFT_BRACKET;}
"]"                             {recordToken(strdup(yytext), yyleng); if (isStreamOpen()) return T_RIGHT_BRACKET;}
"{"                             {recordToken(strdup(yytext), yyleng); if (isStreamOpen()) return T_LEFT_CURLY_BRACKET;}
"}"                             {recordToken(strdup(yytext), yyleng); if (isStreamOpen()) return T_RIGHT_CURLY_BRACKET;}
","                             {recordToken(strdup(yytext), yyleng); if (isStreamOpen()) return T_COMMA;}
"."                             {recordToken(strdup(yytext), yyleng); if (isStreamOpen()) return T_DOT;}
"=="                            {recordToken(strdup(yytext), yyleng); if (isStreamOpen()) return T_REL_EQUAL;}
"!="                            {recordToken(strdup(yytext), yyleng); if (isStreamOpen()) return T_REL_NOT_EQUAL;}
">"                             {recordToken(strdup(yytext), yyleng); if (isStreamOpen()) return T_REL_GREAT;}
"<"                             {recordToken(strdup(yytext), yyleng); if (isStreamOpen()) return T_REL_SMALL;}
">="                            {recordToken(strdup(yytext), yyleng); if (isStreamOpen()) return T_REL_GREAT_EQUAL;}
"<="                            {recordToken(strdup(yytext), yyleng); if (isStreamOpen()) return T_REL_SMALL_EQUAL;}
\&\&|and                        {recordToken(strdup(yytext), yyleng); if (isStreamOpen()) return T_LOGIC_AND;}
\|\||or                         {recordToken(strdup(yytext), yyleng); if (isStreamOpen()) return T_LOGIC_OR;}
\!|not                          {recordToken(strdup(yytext), yyleng); if (isStreamOpen()) return T_LOGIC_NOT;}
"&"                             {recordToken(strdup(yytext), yyleng); if (isStreamOpen()) return T_BITWISE_AND;}
"|"                             {recordToken(strdup(yytext), yyleng); if (isStreamOpen()) return T_BITWISE_OR;}
"^"                             {recordToken(strdup(yytext), yyleng); if (isStreamOpen()) return T_BITWISE_XOR;}
"~"                             {recordToken(strdup(yytext), yyleng); if (isStreamOpen()) return T_BITWISE_NOT;}
"<<"                            {recordToken(strdup(yytext), yyleng); if (isStreamOpen()) return T_BITWISE_LEFT_SHIFT;}
">>"                            {recordToken(strdup(yytext), yyleng); if (isStreamOpen()) return T_BITWISE_RIGHT_SHIFT;}
"++"                            {recordToken(strdup(yytext), yyleng); if (isStreamOpen()) return T_INCREMENT;}
"--"                            {recordToken(strdup(yytext), yyleng); if (isStreamOpen()) return T_DECREMENT;}
"//".*"\n"                      {yylineno++; return T_NEWLINE;}
"#".*"\n"                       {yylineno++; return T_NEWLINE;}
":"                             {recordToken(strdup(yytext), yyleng); return T_COLON;}
"exit"                          {recordToken(strdup(yytext), yyleng); if (isStreamOpen()) return T_QUIT;}
"quit"                          {recordToken(strdup(yytext), yyleng); if (isStreamOpen()) return T_QUIT;}
"print"                         {recordToken(strdup(yytext), yyleng); if (isStreamOpen()) return T_PRINT;}
"echo"                          {recordToken(strdup(yytext), yyleng); if (isStreamOpen()) return T_ECHO;}
"pretty"                        {recordToken(strdup(yytext), yyleng); if (isStreamOpen()) return T_PRETTY;}
"true"                          {recordToken(strdup(yytext), yyleng); yylval.bval = 1; if (isStreamOpen()) return T_TRUE;}
"false"                         {recordToken(strdup(yytext), yyleng); yylval.bval = 0; if (isStreamOpen()) return T_FALSE;}
"symbol_table"                  {recordToken(strdup(yytext), yyleng); if (isStreamOpen()) return T_SYMBOL_TABLE;}
"function_table"                {recordToken(strdup(yytext), yyleng); if (isStreamOpen()) return T_FUNCTION_TABLE;}
"del"                           {recordToken(strdup(yytext), yyleng); if (isStreamOpen()) return T_DEL;}
"return"                        {recordToken(strdup(yytext), yyleng); if (isStreamOpen()) return T_RETURN;}
"default"                       {if (isStreamOpen()) return T_DEFAULT;}

"times do"                      {recordToken(strdup(yytext), yyleng); return T_TIMES_DO;}
"end"                           {recordToken(strdup(yytext), yyleng); return T_END;}
"foreach"                       {recordToken(strdup(yytext), yyleng); return T_FOREACH;}
"as"                            {recordToken(strdup(yytext), yyleng); return T_AS;}
"from"                          {recordToken(strdup(yytext), yyleng); return T_FROM;}
"INFINITE"                      {recordToken(strdup(yytext), yyleng); return T_INFINITE;}

"/*"                            {BEGIN(COMMENT);}
<COMMENT>"*/"                   {BEGIN(INITIAL);}
<COMMENT>.|"\n"                 {yylineno++;}

(\"|\')([^\\(\"|\')]|\\.)*(\"|\') {
    recordToken(strdup(yytext), yyleng);
    if (isStreamOpen()) {
        yylval.sval = (char*)calloc(strlen(yytext)-1, sizeof(char));
        strncpy(yylval.sval, &yytext[1], strlen(yytext)-2);
        return T_STRING;
    }
}

bool|boolean                    {recordToken(strdup(yytext), yyleng); if (isStreamOpen()) return T_VAR_BOOL;}
num|number                      {recordToken(strdup(yytext), yyleng); if (isStreamOpen()) return T_VAR_NUMBER;}
str|string                      {recordToken(strdup(yytext), yyleng); if (isStreamOpen()) return T_VAR_STRING;}
list|array                      {recordToken(strdup(yytext), yyleng); if (isStreamOpen()) return T_VAR_ARRAY;}
json|dict                       {recordToken(strdup(yytext), yyleng); if (isStreamOpen()) return T_VAR_DICT;}
any                             {recordToken(strdup(yytext), yyleng); if (isStreamOpen()) return T_VAR_ANY;}
void|null|nil                   {recordToken(strdup(yytext), yyleng); if (isStreamOpen()) return T_VOID;}
func|function|def               {recordToken(strdup(yytext), yyleng); return T_FUNCTION;}
import|include|use              {recordToken(strdup(yytext), yyleng); return T_IMPORT;}
[a-zA-Z_][a-zA-Z0-9_]*            {bool was_foreach = isForeach(); recordToken(strdup(yytext), yyleng); if ((isStreamOpen()) || was_foreach) { yylval.sval=strdup(yytext); return T_VAR; } }
%%
