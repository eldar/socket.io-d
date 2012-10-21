module socketio.util;

import
    std.exception,
    std.random,
    std.uuid;

@safe nothrow pure char toChar(size_t i)
{
    if(i <= 9)
        return cast(char)('0' + i);
    else
        return cast(char)('a' + (i-10));
}

string generateId()
{
    auto result = new char[32];
    auto uuid = randomUUID();
    size_t i = 0;
    foreach(entry; uuid.data)
    {
        const size_t hi = (entry >> 4) & 0x0F;
        result[i++] = toChar(hi);

        const size_t lo = (entry) & 0x0F;
        result[i++] = toChar(lo);
    }
    return assumeUnique(result);
}
