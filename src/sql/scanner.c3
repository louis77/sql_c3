module sql;

import std::io;

macro @set_null_value(dest, #value, is_null) @private
{
	if (is_null) {
		*dest = null;
	} else {
		**dest = #value;
	}
}

macro @convert_builder_value(builder, dest, is_null)
{
	switch (dest) {
		case String:
			*dest = builder.str_view();
		case String*:
			@set_null_value(dest, builder.str_view(), is_null);
		case ZString:
			*dest = builder.zstr_view();
		case ZString*:
			@set_null_value(dest, builder.zstr_view(), is_null);
		case bool:
			*dest = (builder.str_view() == "1" || builder.str_view() == "t") ? true : false;
		case bool*:
			@set_null_value(dest, (builder.str_view() == "1" || builder.str_view() == "t") ? true : false, is_null);
		case int:
			*dest = builder.str_view().to_int()!;
		case int*:
			@set_null_value(dest, builder.str_view().to_int()!, is_null);
		case int128:
			*dest = builder.str_view().to_int128()!;
		case int128*:
			@set_null_value(dest, builder.str_view().to_int128()!, is_null);
		case long:
			*dest = builder.str_view().to_long()!;
		case long*:
			@set_null_value(dest, builder.str_view().to_long()!, is_null);
		case short:
			*dest = builder.str_view().to_short()!;
		case short*:
			@set_null_value(dest, builder.str_view().to_short()!, is_null);
		case ichar:
			*dest = builder.str_view().to_ichar()!;
		case ichar*:
			@set_null_value(dest, builder.str_view().to_ichar()!, is_null);
		case uint128:
			*dest = builder.str_view().to_uint128()!;
		case uint128*:
			@set_null_value(dest, builder.str_view().to_uint128()!, is_null);
		case ulong:
			*dest = builder.str_view().to_ulong()!;
		case ulong*:
			@set_null_value(dest, builder.str_view().to_ulong()!, is_null);
		case uint:
			*dest = builder.str_view().to_uint()!;
		case uint*:
			@set_null_value(dest, builder.str_view().to_uint()!, is_null);
		case ushort:
			*dest = builder.str_view().to_ushort()!;
		case ushort*:
			@set_null_value(dest, builder.str_view().to_ushort()!, is_null);
		case char:
			*dest = builder.str_view().to_uchar()!;
		case char*:
			@set_null_value(dest, builder.str_view().to_uchar()!, is_null);
		case double:
			*dest = builder.str_view().to_double()!;
		case double*:
			@set_null_value(dest, builder.str_view().to_double()!, is_null);
		case float:
			*dest = builder.str_view().to_float()!;
		case float*:
			@set_null_value(dest, builder.str_view().to_float()!, is_null);
		default:
			return Error.UNSUPPORTED_SCAN_TYPE?;
	}
}