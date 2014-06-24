using OpenDMLib;

/*
 * dm_weblib
 * (c) 2014 by DocuMatrix GmbH
 * see README.txt for more information
 */

namespace DMWebLib
{
  /**
   * This namespace contains the string representation of some mime types.
   */
  namespace MimeType
  {
    public static const string JSON = "application/json";
    public static const string JAVASCRIPT = "text/javascript";
    public static const string HTML = "text/html";
  }

  namespace WebServer
  {
    namespace StatusCode
    {
      public const string NOT_FOUND = "HTTP/1.1 404 Not Found\n";
      public const string OK = "HTTP/1.1 200 OK\n";
      public const string INTERNAL_SERVER_ERROR = "HTTP/1.1 500 Internal Server Error\n";
    }

    public class Request : GLib.Object
    {
      public string full_request;
      public string path;
      public string query;
      public HashTable<string?,string?> args;
      public string object;
      public string action;
      public string val;
      public string method;

      public void dump( )
      {
        stdout.printf( "\n\nNew Request - path: %s\n", this.path );
        if ( args == null )
        {
          stdout.printf( "No parameters\n" );
        }
        else
        {
          stdout.printf( "Parameters:\n" );
          foreach ( string key in args.get_keys( ) )
          {
            stdout.printf( "  --> %s: %s\n", key, args[ key ] );
          }
        }
      }
    }

    public class Response : GLib.Object
    {
      public string status_code;
      public string content_type;
      public string text;
      public uint8[] data;
      public HashTable<string?,string?> headers = new HashTable<string?,string?>( str_hash, str_equal );
    }

    public class Server : GLib.Object
    {
      public uint16 port;
      private ThreadedSocketService tss;

      public signal Response handler( Request request, DataInputStream dis );

      public Server( uint16 port = 80, uint16 max_threads = 10 )
      {
        this.port = port;

        this.tss = new ThreadedSocketService( max_threads );

        InetAddress ia = new InetAddress.any( SocketFamily.IPV4 );
        InetSocketAddress isa = new InetSocketAddress( ia, this.port );
        try
        {
          tss.add_address( isa, SocketType.STREAM, SocketProtocol.TCP, null, null );
        }
        catch( Error e )
        {
          stderr.printf( e.message + "\n" );
          return;
        }

        tss.run.connect( connection_handler );
      }

      public void start( )
      {
        tss.start( );
        stdout.printf( @"Serving on port $(this.port)\n" );
      }

      private bool connection_handler( SocketConnection connection )
      {
        string first_line = "";
        size_t size = 0;
        Request? request = null;
        int64 start_time = GLib.get_real_time( );

        DataInputStream dis = new DataInputStream( connection.input_stream );
        DataOutputStream dos = new DataOutputStream( connection.output_stream );

        /* read the first line from the input stream */
        try
        {
          first_line = dis.read_line( out size );
          stdout.printf( "New request - first_line: %s\n", first_line );
          request = get_request( first_line, dis );
          Response response = this.handler( request, dis );
          this.serve_response( response, dos );
        }
        catch ( Error e )
        {
          stderr.printf( e.message + "\n" );
        }
        int64 end_time = GLib.get_real_time( );
        stdout.printf( "\nRequest done in %s µsec\n", ( end_time - start_time ).to_string( ) );

        return false;
      }

      private void serve_response( Response response, DataOutputStream dos )
      {
        try
        {
          uint8[] data = "No data".data;
          if ( response.text != null )
          {
            data = response.text.data;
          }
          if ( response.data != null )
          {
            data = response.data;
          }
          dos.put_string( response.status_code ?? StatusCode.INTERNAL_SERVER_ERROR );
          dos.put_string( "Server: DMWebServer\n" );
          dos.put_string( "Content-Type: %s\n".printf( response.content_type ) );
          dos.put_string( "Content-Length: %d\n".printf( data.length ) );
          foreach ( string key in response.headers.get_keys( ) )
          {
            dos.put_string( "%s: %s\n".printf( key, response.headers[ key ] ) );
          }
          dos.put_string( "\n" ); //this is the end of the return headers
          /* For long string writes, a loop should be used,
           * because sometimes not all data can be written in one run
           *  see http://live.gnome.org/Vala/GIOSamples#Writing_Data
           */
          long written = 0;
          while ( written < data.length )
          {
            // sum of the bytes of 'text' that already have been written to the stream
            written += dos.write( data[ written:data.length ] );
          }
        }
        catch( Error e )
        {
          stderr.printf( e.message + "\n" );
        }
      }

      // return a Request based on a portion of th line
      private Request get_request( string line, DataInputStream dis )
      {
        Request r = new Request();
        r.args = new HashTable<string?, string?>( str_hash, str_equal );

        //get the parts from the line
        string[] parts = line.split(" ");

        //how many parts are there?
        if (parts.length == 1) {
          return r;
        }

        r.method = parts[ 0 ];

        //add the path to the Request
        r.full_request = parts[ 1 ];

        parts = r.full_request.split( "?" );
        r.path = parts[ 0 ];
        r.query = parts[ 1 ] ?? "";

        //get the object and action
        parts = r.path.split( "/" );
        if ( parts.length > 1 )
        {
          r.object = parts[ 1 ] ?? "";
        }
        if ( parts.length > 2 )
        {
          r.action = parts[ 2 ] ?? "";
        }
        if ( parts.length > 3 )
        {
          r.val = Uri.unescape_string( parts[ 3 ] ) ?? "";
        }

        //split the query if it exists
        if ( r.query != "" )
        {
          string[] query_parts = { };
          parts = r.query.split( "&" );
          foreach( string part in parts )
          {
            query_parts = part.split( "=" );
            if ( query_parts.length == 2 )
            {
              r.args[ query_parts[ 0 ] ] = Uri.unescape_string( query_parts[ 1 ].replace( "+", " " ) );
            }
          }
        }

        size_t length;
        string? new_line;
        while ( ( new_line = dis.read_line( out length ) ) != null )
        {
          if ( new_line.strip( ) == "" )
          {
            break;
          }
          string[] tokens = new_line.split( ": " );
          r.args[ tokens[ 0 ] ] = tokens[ 1 ];
          r.args[ tokens[ 0 ].down( ) ] = tokens[ 1 ];
        }

        if ( r.method == "POST" )
        {
          size_t content_length = (size_t)int64.parse( r.args[ "content-length" ] );
          uint8[] buffer = new uint8[ content_length ];
          ssize_t bytes_read = dis.read( buffer );
          string[] arg_parts = { };
          if ( buffer[ buffer.length - 1 ] != 0x00 )
          {
            buffer += 0x00;
          }
          parts = ((string)buffer).split( "&" );
          foreach( string part in parts )
          {
            arg_parts = part.split( "=" );
            if ( arg_parts.length == 2 )
            {
              r.args[ arg_parts[ 0 ] ] = Uri.unescape_string( arg_parts[ 1 ].replace( "+", " " ) );
            }
          }
        }

        return r;
      }
    }
  }

  public static const uint8 HANDLER_TYPE_DIRECTORY = 1;
  public static const uint8 HANDLER_TYPE_ARCHIVE = 2; // NOT SUPPORTED -> see README.txt and archive-Branch
  public static const uint8 HANDLER_TYPE_CALLBACK = 3;

  public delegate WebServer.Response handler_callback( Server server, WebServer.Request request, DataInputStream dis );

  public class Handler : GLib.Object
  {
    public uint8 type;
    public string path;
    public string? source;

    public handler_callback callback;

    public HashTable<string?,string?> mime_cache = new HashTable<string?,string?>( str_hash, str_equal );

    public Server srv;

    public Handler( uint8 type, string path, string? source, handler_callback? callback, Server srv )
    {
      this.type = type;
      this.path = path;
      if ( source != null && this.type == HANDLER_TYPE_DIRECTORY )
      {
        this.source = OpenDMLib.get_dir( source ).slice( 0, -1 );
      }
      else
      {
        this.source = source;
      }
      this.srv = srv;
      this.callback = callback;
    }

    public WebServer.Response resource_handler(
                                    Server server,
                                    WebServer.Request request,
                                    DataInputStream dis
                                 )
    {
      WebServer.Response response = new WebServer.Response( );
      request.dump( );

      response.headers[ "Connection" ] = "close";
      response.status_code = WebServer.StatusCode.OK;

      if ( this.type == HANDLER_TYPE_ARCHIVE )
      {
        response.status_code = WebServer.StatusCode.INTERNAL_SERVER_ERROR;
        return response;
      }
      else
      {
        string file_name = this.source + request.path;
        if ( !OpenDMLib.IO.file_exists( file_name ) )
        {
          stderr.printf( "File %s does not exist!\n", file_name );
          response.status_code = WebServer.StatusCode.NOT_FOUND;
          return response;
        }

        try
        {
          string? mime_type = this.mime_cache[ file_name ];
          if ( mime_type == null )
          {
            mime_type = OpenDMLib.IO.get_mime_type( file_name );
            if ( mime_type == null )
            {
              mime_type = "text/plain";
            }
            this.mime_cache[ file_name ] = mime_type;
          }
          uint8[] content = null;
          if ( !FileUtils.get_data( file_name, out content ) )
          {
            stderr.printf( "Could not read data from file %s!\n", file_name );
            response.status_code = WebServer.StatusCode.INTERNAL_SERVER_ERROR;
            return response;
          }
          response.status_code = WebServer.StatusCode.OK;
          response.content_type = mime_type;
          response.data = content;
          return response;
        }
        catch ( Error e )
        {
          stderr.printf( "Error while sending file %s! %s\n", file_name, e.message );
          response.status_code = WebServer.StatusCode.INTERNAL_SERVER_ERROR;
          return response;
        }
      }
    }

    public WebServer.Response callback_handler(
                                    Server server,
                                    WebServer.Request request,
                                    DataInputStream dis
                                 )
    {
      request.dump( );

      return this.callback( server, request, dis );
    }
  }

  public class Server : GLib.Object
  {
    private WebServer.Server server;

    private uint16 port;

    private Handler[] handlers;

    public Thread<void*> server_thread;

    public Server( uint16 port, uint8 threads = 10 )
    {
      this.server = new WebServer.Server( port, threads );
      this.port = port;

      this.handlers = { };

      this.server.handler.connect( this.handler );
    }

    public WebServer.Response handler( WebServer.Request request, DataInputStream dis )
    {
      /* Zuständigen Handler finden... */
      Handler? handler = null;
      stdout.printf( "looping %d handlers\n", this.handlers.length );
      for ( int i = 0; i < this.handlers.length; i ++ )
      {
        Handler h = this.handlers[ i ];

        stdout.printf( "request.path: %s, h.path: %s\n", request.path, h.path );
        if ( request.path.has_prefix( h.path ) )
        {
          stdout.printf( "request.path: %s, h.path: %s\n", request.path, h.path );
          if ( handler != null )
          {
            stdout.printf( "handler length: %d, h length: %d\n", handler.path.length, h.path.length );
          }
          if (
               handler == null ||
               handler.path.length < h.path.length
             )
          {
            handler = h;
          }
        }
      }

      WebServer.Response? response = null;
      if ( handler == null )
      {
        response = new WebServer.Response( );
        response.status_code = WebServer.StatusCode.NOT_FOUND;
        response.content_type = "text/html";
        response.text = @"<html><head><title>Not found</title></head><body>$(request.path) not found!</body></html>";
      }
      else
      {
        if ( handler.type == HANDLER_TYPE_CALLBACK )
        {
          response = handler.callback_handler( this, request, dis );
          stdout.printf( "---- response: %s\n", response.text );
        }
        else
        {
          response = handler.resource_handler( this, request, dis );
        }
      }

      return response;
    }

    public void run( )
    {
      this.server_thread = new Thread<void*>( "WebServer", this._threaded_run );
    }

    private void* _threaded_run( )
    {
      this.server.start( );
      return null;
    }

    public void quit( )
    {
      this.server_thread.join( );
    }

    public void add_resource_dir( string path, string directory )
    {
      Handler h = new Handler( HANDLER_TYPE_DIRECTORY, path, directory, null, this );
      this.handlers += h;
      //this.soup_server.add_handler( path, h.resource_handler );
    }

    public void add_callback( string path, handler_callback callback )
    {
      Handler h = new Handler( HANDLER_TYPE_CALLBACK, path, null, callback, this );
      this.handlers += h;
      //this.soup_server.add_handler( path, h.callback_handler );
    }
  }
}
