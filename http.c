#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/un.h>

#define FCGI_VERSION_1           1
#define FCGI_BEGIN_REQUEST       1
#define FCGI_PARAMS              4
#define FCGI_STDIN               5
#define FCGI_STDOUT              6
#define FCGI_STDERR              7
#define FCGI_END_REQUEST         3
#define FCGI_RESPONDER           1

struct fcgi_header {
	    unsigned char version;
	        unsigned char type;
		    unsigned char requestIdB1;
		        unsigned char requestIdB0;
			    unsigned char contentLengthB1;
			        unsigned char contentLengthB0;
				    unsigned char paddingLength;
				        unsigned char reserved;
};

struct fcgi_begin_request_body {
	    unsigned char roleB1;
	        unsigned char roleB0;
		    unsigned char flags;
		        unsigned char reserved[5];
};

void send_fcgi_header(int sock, unsigned char type, unsigned short requestId,
		                      unsigned short contentLength, unsigned char paddingLength) {
	    struct fcgi_header header;
	        header.version = FCGI_VERSION_1;
		    header.type = type;
		        header.requestIdB1 = (requestId >> 8) & 0xFF;
			    header.requestIdB0 = requestId & 0xFF;
			        header.contentLengthB1 = (contentLength >> 8) & 0xFF;
				    header.contentLengthB0 = contentLength & 0xFF;
				        header.paddingLength = paddingLength;
					    header.reserved = 0;
					        write(sock, &header, sizeof(header));
}

void send_begin_request(int sock, unsigned short requestId) {
	    struct fcgi_begin_request_body body = {
		            .roleB1 = 0,
			            .roleB0 = FCGI_RESPONDER,
				            .flags = 0,
					            .reserved = {0}
			        };
	        send_fcgi_header(sock, FCGI_BEGIN_REQUEST, requestId, sizeof(body), 0);
		    write(sock, &body, sizeof(body));
}

void send_param(int sock, unsigned short requestId, const char *name, const char *value) {
	    unsigned char buffer[1024];
	        int name_len = strlen(name);
		    int value_len = strlen(value);
		        int index = 0;

			    if (name_len < 128)
				            buffer[index++] = name_len;
			        else {
					        buffer[index++] = (name_len >> 24) | 0x80;
						        buffer[index++] = (name_len >> 16) & 0xFF;
							        buffer[index++] = (name_len >> 8) & 0xFF;
								        buffer[index++] = name_len & 0xFF;
									    }

				    if (value_len < 128)
					            buffer[index++] = value_len;
				        else {
						        buffer[index++] = (value_len >> 24) | 0x80;
							        buffer[index++] = (value_len >> 16) & 0xFF;
								        buffer[index++] = (value_len >> 8) & 0xFF;
									        buffer[index++] = value_len & 0xFF;
										    }

					    memcpy(&buffer[index], name, name_len);
					        index += name_len;
						    memcpy(&buffer[index], value, value_len);
						        index += value_len;

							    send_fcgi_header(sock, FCGI_PARAMS, requestId, index, 0);
							        write(sock, buffer, index);
}

void end_params(int sock, unsigned short requestId) {
	    send_fcgi_header(sock, FCGI_PARAMS, requestId, 0, 0);
}

void send_empty_stdin(int sock, unsigned short requestId) {
	    send_fcgi_header(sock, FCGI_STDIN, requestId, 0, 0);
}

int main() {
	    int sock;
	        struct sockaddr_un addr;
		    char buffer[4096];
		        ssize_t n;

			    sock = socket(AF_UNIX, SOCK_STREAM, 0);
			        if (sock < 0) return 1;

				    memset(&addr, 0, sizeof(addr));
				        addr.sun_family = AF_UNIX;
					    strcpy(addr.sun_path, "/run/php/php7.0-fpm.sock");

					        if (connect(sock, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
							        close(sock);
								        return 1;
									    }

						    unsigned short requestId = 1;

						        send_begin_request(sock, requestId);
							    send_param(sock, requestId, "SCRIPT_FILENAME", "/home/ahmad/assembly/index.php");
							        send_param(sock, requestId, "REQUEST_METHOD", "GET");
								    send_param(sock, requestId, "CONTENT_LENGTH", "0");
								        send_param(sock, requestId, "SERVER_PROTOCOL", "HTTP/1.1");
									    send_param(sock, requestId, "GATEWAY_INTERFACE", "CGI/1.1");
									        send_param(sock, requestId, "REMOTE_ADDR", "127.0.0.1");
										    send_param(sock, requestId, "SERVER_NAME", "localhost");
										        send_param(sock, requestId, "SERVER_PORT", "80");
											    send_param(sock, requestId, "REQUEST_URI", "/index.php");
											        end_params(sock, requestId);
												    send_empty_stdin(sock, requestId);

												        while (1) {
														        struct fcgi_header header;
															        ssize_t ret = read(sock, &header, sizeof(header));
																        if (ret == 0) break;
																	        if (ret < 0) break;
																		        if (ret != sizeof(header)) break;

																			        unsigned short contentLength = (header.contentLengthB1 << 8) | header.contentLengthB0;
																				        unsigned char paddingLength = header.paddingLength;

																					        if (contentLength > 0) {
																							            ret = read(sock, buffer, contentLength);
																								                if (ret <= 0) break;
																										            if (header.type == FCGI_STDOUT || header.type == FCGI_STDERR) {
																												                    fwrite(buffer, 1, ret, stdout);
																														                    fflush(stdout);
																																                }
																											            }

																						        if (paddingLength > 0) {
																								            char pad[256];
																									                read(sock, pad, paddingLength);
																											        }

																							        if (header.type == FCGI_END_REQUEST) break;
																								    }

													    close(sock);
													        return 0;
}

