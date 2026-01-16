/*
 * cert-hash: 计算 X.509 证书的 subject_hash_old (Android 证书文件名)
 * 用法: cert-hash cert.pem
 * 输出: 8位16进制 hash (如 e4fb11ae)
 * 
 * 纯 C 实现，无外部依赖，可静态编译
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

/* Base64 解码 */
static const unsigned char b64_table[256] = {
    64,64,64,64,64,64,64,64,64,64,64,64,64,64,64,64,
    64,64,64,64,64,64,64,64,64,64,64,64,64,64,64,64,
    64,64,64,64,64,64,64,64,64,64,64,62,64,64,64,63,
    52,53,54,55,56,57,58,59,60,61,64,64,64,64,64,64,
    64, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,
    15,16,17,18,19,20,21,22,23,24,25,64,64,64,64,64,
    64,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,
    41,42,43,44,45,46,47,48,49,50,51,64,64,64,64,64,
    64,64,64,64,64,64,64,64,64,64,64,64,64,64,64,64,
    64,64,64,64,64,64,64,64,64,64,64,64,64,64,64,64,
    64,64,64,64,64,64,64,64,64,64,64,64,64,64,64,64,
    64,64,64,64,64,64,64,64,64,64,64,64,64,64,64,64,
    64,64,64,64,64,64,64,64,64,64,64,64,64,64,64,64,
    64,64,64,64,64,64,64,64,64,64,64,64,64,64,64,64,
    64,64,64,64,64,64,64,64,64,64,64,64,64,64,64,64,
    64,64,64,64,64,64,64,64,64,64,64,64,64,64,64,64
};

static int base64_decode(const char *in, size_t inlen, unsigned char *out, size_t *outlen) {
    size_t i, j = 0;
    unsigned char a, b, c, d;
    
    for (i = 0; i < inlen; ) {
        while (i < inlen && (in[i] == '\n' || in[i] == '\r' || in[i] == ' ')) i++;
        if (i >= inlen) break;
        a = b64_table[(unsigned char)in[i++]];
        
        while (i < inlen && (in[i] == '\n' || in[i] == '\r' || in[i] == ' ')) i++;
        if (i >= inlen) break;
        b = b64_table[(unsigned char)in[i++]];
        
        while (i < inlen && (in[i] == '\n' || in[i] == '\r' || in[i] == ' ')) i++;
        if (i >= inlen) { c = 64; } else { c = b64_table[(unsigned char)in[i++]]; }
        
        while (i < inlen && (in[i] == '\n' || in[i] == '\r' || in[i] == ' ')) i++;
        if (i >= inlen) { d = 64; } else { d = b64_table[(unsigned char)in[i++]]; }
        
        if (a == 64 || b == 64) break;
        
        out[j++] = (a << 2) | (b >> 4);
        if (c != 64) out[j++] = (b << 4) | (c >> 2);
        if (d != 64) out[j++] = (c << 6) | d;
    }
    *outlen = j;
    return 0;
}

/* MD5 实现 */
#define F(x,y,z) ((x & y) | (~x & z))
#define G(x,y,z) ((x & z) | (y & ~z))
#define H(x,y,z) (x ^ y ^ z)
#define I(x,y,z) (y ^ (x | ~z))
#define ROTL(x,n) ((x << n) | (x >> (32 - n)))

static const uint32_t K[64] = {
    0xd76aa478,0xe8c7b756,0x242070db,0xc1bdceee,0xf57c0faf,0x4787c62a,0xa8304613,0xfd469501,
    0x698098d8,0x8b44f7af,0xffff5bb1,0x895cd7be,0x6b901122,0xfd987193,0xa679438e,0x49b40821,
    0xf61e2562,0xc040b340,0x265e5a51,0xe9b6c7aa,0xd62f105d,0x02441453,0xd8a1e681,0xe7d3fbc8,
    0x21e1cde6,0xc33707d6,0xf4d50d87,0x455a14ed,0xa9e3e905,0xfcefa3f8,0x676f02d9,0x8d2a4c8a,
    0xfffa3942,0x8771f681,0x6d9d6122,0xfde5380c,0xa4beea44,0x4bdecfa9,0xf6bb4b60,0xbebfbc70,
    0x289b7ec6,0xeaa127fa,0xd4ef3085,0x04881d05,0xd9d4d039,0xe6db99e5,0x1fa27cf8,0xc4ac5665,
    0xf4292244,0x432aff97,0xab9423a7,0xfc93a039,0x655b59c3,0x8f0ccc92,0xffeff47d,0x85845dd1,
    0x6fa87e4f,0xfe2ce6e0,0xa3014314,0x4e0811a1,0xf7537e82,0xbd3af235,0x2ad7d2bb,0xeb86d391
};
static const int S[64] = {
    7,12,17,22,7,12,17,22,7,12,17,22,7,12,17,22,
    5,9,14,20,5,9,14,20,5,9,14,20,5,9,14,20,
    4,11,16,23,4,11,16,23,4,11,16,23,4,11,16,23,
    6,10,15,21,6,10,15,21,6,10,15,21,6,10,15,21
};

static void md5(const unsigned char *msg, size_t len, unsigned char *digest) {
    uint32_t a0 = 0x67452301, b0 = 0xefcdab89, c0 = 0x98badcfe, d0 = 0x10325476;
    
    size_t padded_len = ((len + 8) / 64 + 1) * 64;
    unsigned char *padded = calloc(padded_len, 1);
    memcpy(padded, msg, len);
    padded[len] = 0x80;
    uint64_t bits = len * 8;
    memcpy(padded + padded_len - 8, &bits, 8);
    
    for (size_t chunk = 0; chunk < padded_len; chunk += 64) {
        uint32_t M[16];
        for (int j = 0; j < 16; j++)
            M[j] = padded[chunk + j*4] | (padded[chunk + j*4 + 1] << 8) |
                   (padded[chunk + j*4 + 2] << 16) | (padded[chunk + j*4 + 3] << 24);
        
        uint32_t A = a0, B = b0, C = c0, D = d0;
        for (int i = 0; i < 64; i++) {
            uint32_t Fn, g;
            if (i < 16) { Fn = F(B,C,D); g = i; }
            else if (i < 32) { Fn = G(B,C,D); g = (5*i + 1) % 16; }
            else if (i < 48) { Fn = H(B,C,D); g = (3*i + 5) % 16; }
            else { Fn = I(B,C,D); g = (7*i) % 16; }
            Fn = Fn + A + K[i] + M[g];
            A = D; D = C; C = B; B = B + ROTL(Fn, S[i]);
        }
        a0 += A; b0 += B; c0 += C; d0 += D;
    }
    free(padded);
    
    for (int i = 0; i < 4; i++) { digest[i] = (a0 >> (i*8)) & 0xff; }
    for (int i = 0; i < 4; i++) { digest[4+i] = (b0 >> (i*8)) & 0xff; }
    for (int i = 0; i < 4; i++) { digest[8+i] = (c0 >> (i*8)) & 0xff; }
    for (int i = 0; i < 4; i++) { digest[12+i] = (d0 >> (i*8)) & 0xff; }
}

/* ASN.1 DER 解析 - 提取 Subject */
static int read_length(const unsigned char *p, size_t *pos, size_t max) {
    if (*pos >= max) return -1;
    int len = p[(*pos)++];
    if ((len & 0x80) == 0) return len;
    int num = len & 0x7f;
    if (num > 4 || *pos + num > max) return -1;
    len = 0;
    for (int i = 0; i < num; i++) len = (len << 8) | p[(*pos)++];
    return len;
}

static int find_subject(const unsigned char *der, size_t der_len, 
                        const unsigned char **subject, size_t *subject_len) {
    size_t pos = 0;
    
    /* Certificate SEQUENCE */
    if (der[pos++] != 0x30) return -1;
    read_length(der, &pos, der_len);
    
    /* TBSCertificate SEQUENCE */
    if (der[pos++] != 0x30) return -1;
    int tbs_len = read_length(der, &pos, der_len);
    if (tbs_len < 0) return -1;
    
    /* Skip version [0] if present */
    if (der[pos] == 0xa0) {
        pos++;
        int vlen = read_length(der, &pos, der_len);
        pos += vlen;
    }
    
    /* Skip serialNumber INTEGER */
    if (der[pos++] != 0x02) return -1;
    int slen = read_length(der, &pos, der_len);
    pos += slen;
    
    /* Skip signature AlgorithmIdentifier SEQUENCE */
    if (der[pos++] != 0x30) return -1;
    int alen = read_length(der, &pos, der_len);
    pos += alen;
    
    /* Skip issuer Name SEQUENCE */
    if (der[pos++] != 0x30) return -1;
    int ilen = read_length(der, &pos, der_len);
    pos += ilen;
    
    /* Skip validity SEQUENCE */
    if (der[pos++] != 0x30) return -1;
    int vlen = read_length(der, &pos, der_len);
    pos += vlen;
    
    /* Subject Name SEQUENCE - this is what we want */
    size_t subject_start = pos;
    if (der[pos++] != 0x30) return -1;
    int subj_len = read_length(der, &pos, der_len);
    if (subj_len < 0) return -1;
    
    *subject = der + subject_start;
    *subject_len = pos - subject_start + subj_len;
    return 0;
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <cert.pem|cert.der>\n", argv[0]);
        return 1;
    }
    
    FILE *f = fopen(argv[1], "rb");
    if (!f) {
        fprintf(stderr, "Cannot open %s\n", argv[1]);
        return 1;
    }
    
    fseek(f, 0, SEEK_END);
    long fsize = ftell(f);
    fseek(f, 0, SEEK_SET);
    
    char *content = malloc(fsize + 1);
    fread(content, 1, fsize, f);
    content[fsize] = 0;
    fclose(f);
    
    unsigned char *der = NULL;
    size_t der_len = 0;
    
    /* Check if PEM or DER */
    if (strstr(content, "-----BEGIN CERTIFICATE-----")) {
        /* PEM format - extract base64 and decode */
        char *start = strstr(content, "-----BEGIN CERTIFICATE-----");
        start += strlen("-----BEGIN CERTIFICATE-----");
        char *end = strstr(start, "-----END CERTIFICATE-----");
        if (!end) {
            fprintf(stderr, "Invalid PEM\n");
            free(content);
            return 1;
        }
        *end = 0;
        
        der = malloc(fsize);
        base64_decode(start, end - start, der, &der_len);
    } else {
        /* Assume DER format */
        der = (unsigned char *)content;
        der_len = fsize;
        content = NULL; /* Don't free twice */
    }
    
    const unsigned char *subject;
    size_t subject_len;
    if (find_subject(der, der_len, &subject, &subject_len) != 0) {
        fprintf(stderr, "Failed to parse certificate\n");
        if (content) free(content);
        if (der != (unsigned char *)content) free(der);
        return 1;
    }
    
    unsigned char digest[16];
    md5(subject, subject_len, digest);
    
    /* subject_hash_old: first 4 bytes of MD5, little-endian */
    uint32_t hash = digest[0] | (digest[1] << 8) | (digest[2] << 16) | (digest[3] << 24);
    printf("%08x\n", hash);
    
    if (content) free(content);
    if (der != (unsigned char *)content) free(der);
    return 0;
}
