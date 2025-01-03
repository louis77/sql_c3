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

fn void! scan_with_function(Scannable arg, ZString builder, bool is_null) @inline @private
{
	if (&arg.decode)
	{
		if (is_null) return;
		arg.decode(builder)!;
		return;
	}

	return Error.UNSUPPORTED_SCAN_TYPE?;
}

macro void! @convert_builder_value(builder, dest, is_null)
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
			scan_with_function((Scannable)dest, builder.zstr_view(), is_null)!;
	}
}

def @SqlName(value) = {
    @tag("sql_name", value)
};

def @SqlOmit = {
    @tag("sql_omit", true)
};

macro Result.@scan_struct(&self, &value)
{
	var $Type = $typeof(*value);
	var col_num = self.num_columns();
    // io::printfn("type is: %s", $Type.nameof);
	// io::printfn("cols: %d", col_num);
	for (usz i = 0; i < col_num; i++)
	{
		$foreach ($idx, $field : $Type.membersof)
//			io::printfn("-> field: %s", $field.nameof);
			var $col_name = $field.nameof;

			$if $field.has_tagof("sql_name"):
				$col_name = $field.tagof("sql_name");
//				io::printfn("   sql name is: %s", $field.tagof("sql_name"));
			$else
			$endif
			$if $field.has_tagof("sql_omit"):
//				io::printfn("   sql omit: %s", $field.tagof("sql_omit"));
			$else
				self.scan_field($idx, &$field.get(*value))!;
			$endif
		$endforeach
	}
}