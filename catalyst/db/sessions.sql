CREATE TABLE sessions (
    id           char(72) primary key,
    session_data blob,
    expires      int(10)
);

