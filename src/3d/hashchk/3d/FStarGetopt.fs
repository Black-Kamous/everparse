#light "off"
module FStarGetopt
open Prims
open FStar_Pervasives

let cmdline : unit  ->  Prims.string Prims.list = (fun ( uu___  :  unit ) -> (OS.argv ()))


let noshort : FStar_Char.char = ' '

type 'a opt_variant =
| ZeroArgs of (unit  ->  'a)
| OneArg of ((Prims.string  ->  'a) * Prims.string)


let uu___is_ZeroArgs = (fun ( projectee  :  'a opt_variant ) -> (match (projectee) with
| ZeroArgs (_0) -> begin
true
end
| uu___ -> begin
false
end))


let __proj__ZeroArgs__item___0 = (fun ( projectee  :  'a opt_variant ) -> (match (projectee) with
| ZeroArgs (_0) -> begin
_0
end))


let uu___is_OneArg = (fun ( projectee  :  'a opt_variant ) -> (match (projectee) with
| OneArg (_0) -> begin
true
end
| uu___ -> begin
false
end))


let __proj__OneArg__item___0 = (fun ( projectee  :  'a opt_variant ) -> (match (projectee) with
| OneArg (_0) -> begin
_0
end))


type 'a opt' =
(FStar_Char.char * Prims.string * 'a opt_variant)


type opt =
unit opt'

type parse_cmdline_res =
| Help
| Error of Prims.string
| Success


let uu___is_Help : parse_cmdline_res  ->  Prims.bool = (fun ( projectee  :  parse_cmdline_res ) -> (match (projectee) with
| Help -> begin
true
end
| uu___ -> begin
false
end))


let uu___is_Error : parse_cmdline_res  ->  Prims.bool = (fun ( projectee  :  parse_cmdline_res ) -> (match (projectee) with
| Error (_0) -> begin
true
end
| uu___ -> begin
false
end))


let __proj__Error__item___0 : parse_cmdline_res  ->  Prims.string = (fun ( projectee  :  parse_cmdline_res ) -> (match (projectee) with
| Error (_0) -> begin
_0
end))


let uu___is_Success : parse_cmdline_res  ->  Prims.bool = (fun ( projectee  :  parse_cmdline_res ) -> (match (projectee) with
| Success -> begin
true
end
| uu___ -> begin
false
end))


let bind : parse_cmdline_res  ->  (unit  ->  parse_cmdline_res)  ->  parse_cmdline_res = (fun ( l  :  parse_cmdline_res ) ( f  :  unit  ->  parse_cmdline_res ) -> (match (l) with
| Help -> begin
l
end
| Error (uu___) -> begin
l
end
| Success -> begin
(f ())
end))


let find_matching_opt : (FStar_String.char * Prims.string * unit opt_variant) Prims.list  ->  Prims.string  ->  (opt FStar_Pervasives_Native.option * Prims.string) FStar_Pervasives_Native.option = (fun ( specs  :  (FStar_String.char * Prims.string * unit opt_variant) Prims.list ) ( s  :  Prims.string ) -> (match (((FStar_String.strlen s) < (Prims.parse_int "2"))) with
| true -> begin
FStar_Pervasives_Native.None
end
| uu___ -> begin
(match ((Prims.op_Equality (FStar_String.sub s (Prims.parse_int "0") (Prims.parse_int "2")) "--")) with
| true -> begin
(

let strim = (FStar_String.sub s (Prims.parse_int "2") ((FStar_String.strlen s) - (Prims.parse_int "2")))
in (

let o = (FStar_List.tryFind (fun ( uu___1  :  (FStar_Char.char * Prims.string * unit opt_variant) ) -> (match (uu___1) with
| (uu___2, option, uu___3) -> begin
(Prims.op_Equality option strim)
end)) specs)
in FStar_Pervasives_Native.Some (((o), (strim)))))
end
| uu___1 -> begin
(match ((Prims.op_Equality (FStar_String.sub s (Prims.parse_int "0") (Prims.parse_int "1")) "-")) with
| true -> begin
(

let strim = (FStar_String.sub s (Prims.parse_int "1") ((FStar_String.strlen s) - (Prims.parse_int "1")))
in (

let o = (FStar_List.tryFind (fun ( uu___2  :  (FStar_String.char * Prims.string * unit opt_variant) ) -> (match (uu___2) with
| (shortoption, uu___3, uu___4) -> begin
(Prims.op_Equality (FStar_String.make (Prims.parse_int "1") shortoption) strim)
end)) specs)
in FStar_Pervasives_Native.Some (((o), (strim)))))
end
| uu___2 -> begin
FStar_Pervasives_Native.None
end)
end)
end))


let rec parse : opt Prims.list  ->  (Prims.string  ->  parse_cmdline_res)  ->  Prims.string Prims.list  ->  Prims.int  ->  Prims.int  ->  Prims.int  ->  parse_cmdline_res = (fun ( opts  :  opt Prims.list ) ( def  :  Prims.string  ->  parse_cmdline_res ) ( ar  :  Prims.string Prims.list ) ( ix  :  Prims.int ) ( max  :  Prims.int ) ( i  :  Prims.int ) -> (match ((ix > max)) with
| true -> begin
Success
end
| uu___ -> begin
(

let arg = (FStar_List.nth ar ix)
in (

let go_on = (fun ( uu___1  :  unit ) -> (

let uu___2 = (def arg)
in (bind uu___2 (fun ( uu___3  :  unit ) -> (parse opts def ar (ix + (Prims.parse_int "1")) max (i + (Prims.parse_int "1")))))))
in (

let uu___1 = (find_matching_opt opts arg)
in (match (uu___1) with
| FStar_Pervasives_Native.None -> begin
(go_on ())
end
| FStar_Pervasives_Native.Some (FStar_Pervasives_Native.None, uu___2) -> begin
Error ((Prims.strcat "unrecognized option \'" (Prims.strcat arg "\'\n")))
end
| FStar_Pervasives_Native.Some (FStar_Pervasives_Native.Some (uu___2, uu___3, p), argtrim) -> begin
(match (p) with
| ZeroArgs (f) -> begin
((f ());
(parse opts def ar (ix + (Prims.parse_int "1")) max (i + (Prims.parse_int "1")));
)
end
| OneArg (f, uu___4) -> begin
(match (((ix + (Prims.parse_int "1")) > max)) with
| true -> begin
Error ((Prims.strcat "last option \'" (Prims.strcat argtrim "\' takes an argument but has none\n")))
end
| uu___5 -> begin
(

let r = (FStar_All.try_with (fun ( uu___6  :  unit ) -> (match (()) with
| () -> begin
((

let uu___8 = (FStar_List.nth ar (ix + (Prims.parse_int "1")))
in (f uu___8));
Success;
)
end)) (fun ( uu___6  :  Prims.exn ) -> Error ((Prims.strcat "wrong argument given to option `" (Prims.strcat argtrim "`\n")))))
in (bind r (fun ( uu___6  :  unit ) -> (parse opts def ar (ix + (Prims.parse_int "2")) max (i + (Prims.parse_int "1"))))))
end)
end)
end))))
end))


let parse_array : opt Prims.list  ->  (Prims.string  ->  parse_cmdline_res)  ->  Prims.string Prims.list  ->  Prims.int  ->  parse_cmdline_res = (fun ( specs  :  opt Prims.list ) ( others  :  Prims.string  ->  parse_cmdline_res ) ( args  :  Prims.string Prims.list ) ( offset  :  Prims.int ) -> (parse specs others args offset ((FStar_List_Tot_Base.length args) - (Prims.parse_int "1")) (Prims.parse_int "0")))


let parse_cmdline : opt Prims.list  ->  (Prims.string  ->  parse_cmdline_res)  ->  parse_cmdline_res = (fun ( specs  :  opt Prims.list ) ( others  :  Prims.string  ->  parse_cmdline_res ) -> (

let uu___ = (cmdline ())
in (parse_array specs others uu___ (Prims.parse_int "1"))))


let parse_string : opt Prims.list  ->  (Prims.string  ->  parse_cmdline_res)  ->  Prims.string  ->  parse_cmdline_res = (fun ( specs  :  opt Prims.list ) ( others  :  Prims.string  ->  parse_cmdline_res ) ( str  :  Prims.string ) -> (

let split_spaces = (fun ( str1  :  Prims.string ) -> (

let _space = (fun ( uu___  :  unit ) -> " ")
in (

let _tab = (fun ( uu___  :  unit ) -> "\t")
in (

let space = (_space ())
in (

let tab = (_tab ())
in (

let seps = ((FStar_String.index space (Prims.parse_int "0")))::((FStar_String.index tab (Prims.parse_int "0")))::[]
in (FStar_List.filter (fun ( s  :  Prims.string ) -> (Prims.op_disEquality s "")) (FStar_String.split seps str1))))))))
in (

let index_of = (fun ( str1  :  Prims.string ) ( c  :  FStar_String.char ) -> (

let res = (FStar_String.index_of str1 c)
in (match (((res < (Prims.parse_int "0")) || (res >= (FStar_String.strlen str1)))) with
| true -> begin
(Prims.parse_int "-1")
end
| uu___ -> begin
res
end)))
in (

let substring_from = (fun ( s  :  Prims.string ) ( j  :  Prims.int ) -> (match ((j > (FStar_String.strlen s))) with
| true -> begin
""
end
| uu___ -> begin
(

let len = ((FStar_String.strlen s) - j)
in (FStar_String.sub s j len))
end))
in (

let rec split_quoted_fragments : Prims.string  ->  Prims.string Prims.list FStar_Pervasives_Native.option = (fun ( str1  :  Prims.string ) -> (

let i = (index_of str1 ''')
in (match ((i < (Prims.parse_int "0"))) with
| true -> begin
(

let uu___ = (split_spaces str1)
in FStar_Pervasives_Native.Some (uu___))
end
| uu___ -> begin
(

let prefix = (FStar_String.sub str1 (Prims.parse_int "0") i)
in (

let suffix = (substring_from str1 (i + (Prims.parse_int "1")))
in (

let j = (index_of suffix ''')
in (match ((j < (Prims.parse_int "0"))) with
| true -> begin
FStar_Pervasives_Native.None
end
| uu___1 -> begin
(

let quoted_frag = (FStar_String.sub suffix (Prims.parse_int "0") j)
in (

let rest = (split_quoted_fragments (substring_from suffix (j + (Prims.parse_int "1"))))
in (match (rest) with
| FStar_Pervasives_Native.None -> begin
FStar_Pervasives_Native.None
end
| FStar_Pervasives_Native.Some (rest1) -> begin
(

let uu___2 = (

let uu___3 = (split_spaces prefix)
in (FStar_List_Tot_Base.append uu___3 ((quoted_frag)::rest1)))
in FStar_Pervasives_Native.Some (uu___2))
end)))
end))))
end)))
in (

let uu___ = (split_quoted_fragments str)
in (match (uu___) with
| FStar_Pervasives_Native.None -> begin
Error ("Failed to parse options; unmatched quote \"\'\"")
end
| FStar_Pervasives_Native.Some (args) -> begin
(parse_array specs others args (Prims.parse_int "0"))
end)))))))


let parse_list : opt Prims.list  ->  (Prims.string  ->  parse_cmdline_res)  ->  Prims.string Prims.list  ->  parse_cmdline_res = (fun ( specs  :  opt Prims.list ) ( others  :  Prims.string  ->  parse_cmdline_res ) ( lst  :  Prims.string Prims.list ) -> (parse_array specs others lst (Prims.parse_int "0")))




