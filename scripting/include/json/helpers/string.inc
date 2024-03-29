/**
 * vim: set ts=4 :
 * =============================================================================
 * sm-json
 * Provides a pure SourcePawn implementation of JSON encoding and decoding.
 * https://github.com/clugg/sm-json
 *
 * sm-json (C)2020 James Dickens. (clug)
 * SourceMod (C)2004-2008 AlliedModders LLC.  All rights reserved.
 * =============================================================================
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * As a special exception, AlliedModders LLC gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2," the
 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software
 * by the Valve Corporation.  You must obey the GNU General Public License in
 * all respects for all other code used.  Additionally, AlliedModders LLC grants
 * this exception to all derivative works.  AlliedModders LLC defines further
 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),
 * or <http://www.sourcemod.net/license.php>.
 */

#if defined _json_helpers_string_included
 #endinput
#endif
#define _json_helpers_string_included

/**
 * Mapping characters to their escaped form.
 */
char JSON_STRING_NORMAL[][]  = {
    "\\",   "\"",   "/",   "\b",  "\f",  "\n",  "\r",  "\t"
};
char JSON_STRING_ESCAPED[][] = {
    "\\\\", "\\\"", "\\/", "\\b", "\\f", "\\n", "\\r", "\\t"
};

/**
 * Escapes a string in-place in a buffer.
 *
 * @param buffer    String buffer.
 * @param max_size  Maximum size of string buffer.
 */
stock void json_escape_string(char[] buffer, int max_size)
{
    for (int i = 0; i < sizeof(JSON_STRING_NORMAL); i += 1) {
        ReplaceString(
            buffer,
            max_size,
            JSON_STRING_NORMAL[i],
            JSON_STRING_ESCAPED[i]
        );
    }
}

/**
 * Unescapes a string in-place in a buffer.
 *
 * @param buffer    String buffer.
 * @param max_size  Maximum size of string buffer.
 */
stock void json_unescape_string(char[] buffer, int max_size)
{
    for (int i = 0; i < sizeof(JSON_STRING_NORMAL); i += 1) {
        ReplaceString(
            buffer,
            max_size,
            JSON_STRING_ESCAPED[i],
            JSON_STRING_NORMAL[i]
        );
    }
}

/**
 * Checks if a string starts with another string.
 *
 * @param haystack  String to check that starts with needle.
 * @param max_size  Maximum size of string buffer.
 * @param needle    String to check that haystack starts with.
 * @returns         True if haystack begins with needle, false otherwise.
 */
stock bool json_string_startswith(const char[] haystack, const char[] needle)
{
    int haystack_length = strlen(haystack);
    int needle_length = strlen(needle);
    if (needle_length > haystack_length) {
        return false;
    }

    for (int i = 0; i < needle_length; i += 1) {
        if (haystack[i] != needle[i]) {
            return false;
        }
    }

    return true;
}

/**
 * Checks if a string ends with another string.
 *
 * @param haystack  String to check that ends with needle.
 * @param max_size  Maximum size of string buffer.
 * @param needle    String to check that haystack ends with.
 * @returns         True if haystack ends with needle, false otherwise.
 */
stock bool json_string_endswith(const char[] haystack, const char[] needle)
{
    int haystack_length = strlen(haystack);
    int needle_length = strlen(needle);
    if (needle_length > haystack_length) {
        return false;
    }

    for (int i = 0; i < needle_length; i += 1) {
        if (haystack[haystack_length - needle_length + i] != needle[i]) {
            return false;
        }
    }

    return true;
}
