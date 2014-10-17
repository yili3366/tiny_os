SECTIONS
{
	. = 0x1000;
	.text : {
	*(.text)
	} = 0

	.data : {
	*(.data)
	}
	
	.bss : {
	*(.bss)
	}	
}
