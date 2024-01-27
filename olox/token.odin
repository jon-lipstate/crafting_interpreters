package crafting_interpeters

Token :: struct {
	type: Token_Type,
	text: string,
	line: int,
}
Token_Type :: enum {
	Invalid,
	// Single-Char Tokens
	Left_Paren,
	Right_Paren,
	Left_Brace,
	Right_Brace,
	Comma,
	Dot,
	Minus,
	Plus,
	Semi_Colon,
	Slash,
	Star,
	// One or two character tokens.
	Bang,
	Bang_Equal,
	Equal,
	Equal_Equal,
	Greater,
	Greater_Equal,
	Less,
	Less_Equal,
	// Literals.
	Identifier,
	String,
	Number,
	// Keywords.
	And,
	Class,
	Else,
	False,
	For,
	Fun,
	If,
	Nil,
	Or,
	Print,
	Return,
	Super,
	This,
	True,
	Var,
	While,
	EOF,
}
