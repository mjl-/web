Rssgen: module
{
	PATH:	con "/dis/lib/rssgen.dis";

	Item: adt {
		title, link, descr: string;
		time, timetzoff:	int;
		guid:	string;
		cats:	list of string;

		text:	fn(it: self ref Item): string;
	};

	rssgen:	fn(title, link, descr: string, items: list of ref Item): string;
};
