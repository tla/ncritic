CREATE TABLE collations (
    jobid       	char(40) primary key,
    witnesses		blob,
    algorithm		char(20),
    result_format	char(10),
    status		char(10),
    process		int,
    result		blob
);
