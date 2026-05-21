component extends="testbox.system.BaseSpec" output="false" {

  function beforeAll() {
    variables.createdUserIds = [];
    variables.createdStreamIds = [];
    variables.userSeed = 907500000 + randRange( 1000, 99999 );

    var scheme = ( structKeyExists( CGI, "https" ) && CGI.https == "on" ) ? "https" : "http";
    var host = CGI.server_name;
    var port = CGI.server_port;
    var portPart = "";
    if ( !( scheme == "http" && port == 80 ) && !( scheme == "https" && port == 443 ) ) {
      portPart = ":" & port;
    }
    variables.baseUrl = scheme & "://" & host & portPart;
  }

  function afterEach() {
    cleanupVoyageFixtures();
  }

  function run() {
    describe( "Follow voyage stream timestamps", function() {
      it( "serializes post and comment UTC DATETIME values without CF/JDBC timezone drift", function() {
        var ownerUserId = nextUserId();
        var streamId = createPublicStream( ownerUserId );
        var postId = createPost(
          streamId = streamId,
          body = "PROD TEST NOTE timestamp parity",
          createdUtc = "2026-05-21 02:37:35"
        );
        var followerId = createFollower( streamId );
        createComment(
          postId = postId,
          followerId = followerId,
          body = "Follow timestamp comment parity",
          createdUtc = "2026-05-21 02:35:59"
        );

        var payload = apiGetJson(
          variables.baseUrl & "/fpw/api/v1/voyage.cfc?method=handle&action=listPosts&stream_id=" & streamId & "&limit=10&returnFormat=json"
        );

        expect( payload.SUCCESS ).toBeTrue( serializeJSON( payload ) );
        expect( arrayLen( payload.posts ) ).toBeGT( 0, serializeJSON( payload ) );

        var foundPost = {};
        for ( var i = 1; i <= arrayLen( payload.posts ); i++ ) {
          if ( val( payload.posts[ i ].id ) EQ postId ) {
            foundPost = payload.posts[ i ];
            break;
          }
        }

        expect( structCount( foundPost ) ).toBeGT( 0, serializeJSON( payload ) );
        expect( foundPost.created_utc ).toBe( "2026-05-21T02:37:35Z" );
        expect( foundPost.created_utc ).notToBe( "2026-05-20T22:37:35Z" );
        expect( arrayLen( foundPost.comments ) ).toBe( 1, serializeJSON( foundPost ) );
        expect( foundPost.comments[ 1 ].created_utc ).toBe( "2026-05-21T02:35:59Z" );
        expect( foundPost.comments[ 1 ].created_utc ).notToBe( "2026-05-20T22:35:59Z" );
      } );
    } );
  }

  private numeric function nextUserId() {
    variables.userSeed++;
    arrayAppend( variables.createdUserIds, variables.userSeed );
    createAdminCompEntitlement( variables.userSeed );
    return variables.userSeed;
  }

  private void function createAdminCompEntitlement( required numeric userId ) {
    queryExecute(
      "INSERT INTO member_entitlements (
         user_id,
         entitlement_type,
         source,
         status,
         starts_at_utc,
         created_utc,
         updated_utc
       ) VALUES (
         :userId,
         'premium',
         'admin_comp',
         'active',
         UTC_TIMESTAMP(),
         UTC_TIMESTAMP(),
         UTC_TIMESTAMP()
       )",
      {
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
  }

  private numeric function createPublicStream( required numeric ownerUserId ) {
    var slug = "test-follow-timestamp-" & lCase( replace( createUUID(), "-", "", "all" ) );
    var shareToken = lCase( replace( createUUID(), "-", "", "all" ) ) & lCase( replace( createUUID(), "-", "", "all" ) );
    var qNewId = queryNew( "" );

    queryExecute(
      "INSERT INTO voyage_streams (
         floatplan_id,
         owner_user_id,
         slug,
         share_token,
         privacy_mode,
         allow_interactions,
         created_utc,
         updated_utc
       ) VALUES (
         0,
         :ownerUserId,
         :slug,
         :shareToken,
         'public',
         1,
         UTC_TIMESTAMP(),
         UTC_TIMESTAMP()
       )",
      {
        ownerUserId = { value = arguments.ownerUserId, cfsqltype = "cf_sql_integer" },
        slug = { value = slug, cfsqltype = "cf_sql_varchar" },
        shareToken = { value = left( shareToken, 96 ), cfsqltype = "cf_sql_varchar" }
      },
      { datasource = "fpw" }
    );

    qNewId = queryExecute( "SELECT LAST_INSERT_ID() AS id", {}, { datasource = "fpw" } );
    arrayAppend( variables.createdStreamIds, val( qNewId.id[ 1 ] ) );
    return val( qNewId.id[ 1 ] );
  }

  private numeric function createPost(
    required numeric streamId,
    required string body,
    required string createdUtc
  ) {
    var qNewId = queryNew( "" );

    queryExecute(
      "INSERT INTO voyage_posts (
         stream_id,
         author_type,
         title,
         body,
         post_type,
         event_type,
         created_utc
       ) VALUES (
         :streamId,
         'owner',
         'Timestamp parity',
         :body,
         'text',
         'test_timestamp_parity',
         :createdUtc
       )",
      {
        streamId = { value = arguments.streamId, cfsqltype = "cf_sql_integer" },
        body = { value = arguments.body, cfsqltype = "cf_sql_longvarchar" },
        createdUtc = { value = arguments.createdUtc, cfsqltype = "cf_sql_varchar" }
      },
      { datasource = "fpw" }
    );

    qNewId = queryExecute( "SELECT LAST_INSERT_ID() AS id", {}, { datasource = "fpw" } );
    return val( qNewId.id[ 1 ] );
  }

  private numeric function createFollower( required numeric streamId ) {
    var qNewId = queryNew( "" );
    var followerToken = lCase( replace( createUUID(), "-", "", "all" ) ) & lCase( replace( createUUID(), "-", "", "all" ) );

    queryExecute(
      "INSERT INTO voyage_followers (
         stream_id,
         display_name,
         email,
         access_token,
         is_blocked,
         created_utc,
         last_seen_utc
       ) VALUES (
         :streamId,
         'Timestamp Viewer',
         :email,
         :accessToken,
         0,
         UTC_TIMESTAMP(),
         UTC_TIMESTAMP()
       )",
      {
        streamId = { value = arguments.streamId, cfsqltype = "cf_sql_integer" },
        email = { value = "follow-timestamp-" & createUUID() & "@example.com", cfsqltype = "cf_sql_varchar" },
        accessToken = { value = left( followerToken, 96 ), cfsqltype = "cf_sql_varchar" }
      },
      { datasource = "fpw" }
    );

    qNewId = queryExecute( "SELECT LAST_INSERT_ID() AS id", {}, { datasource = "fpw" } );
    return val( qNewId.id[ 1 ] );
  }

  private void function createComment(
    required numeric postId,
    required numeric followerId,
    required string body,
    required string createdUtc
  ) {
    queryExecute(
      "INSERT INTO voyage_comments (
         post_id,
         follower_id,
         body,
         is_deleted,
         created_utc
       ) VALUES (
         :postId,
         :followerId,
         :body,
         0,
         :createdUtc
       )",
      {
        postId = { value = arguments.postId, cfsqltype = "cf_sql_integer" },
        followerId = { value = arguments.followerId, cfsqltype = "cf_sql_integer" },
        body = { value = arguments.body, cfsqltype = "cf_sql_varchar" },
        createdUtc = { value = arguments.createdUtc, cfsqltype = "cf_sql_varchar" }
      },
      { datasource = "fpw" }
    );
  }

  private struct function apiGetJson( required string url ) {
    var res = {};
    var raw = "";
    cfhttp( method = "GET", url = arguments.url, timeout = "60", result = "res" ) {
      cfhttpparam( type = "header", name = "Accept", value = "application/json" );
    }
    raw = structKeyExists( res, "fileContent" ) ? toString( res.fileContent ) : "";
    try {
      var parsed = deserializeJSON( raw );
      if ( isStruct( parsed ) ) return parsed;
      return { SUCCESS = false, MESSAGE = "JSON response was not a struct", raw = raw, parsed = parsed };
    } catch ( any e ) {
      return { SUCCESS = false, MESSAGE = "Response was not JSON", raw = raw, error = e.message };
    }
  }

  private void function cleanupVoyageFixtures() {
    if ( arrayLen( variables.createdStreamIds ) ) {
      queryExecute(
        "DELETE vc
         FROM voyage_comments vc
         INNER JOIN voyage_posts vp ON vp.id = vc.post_id
         WHERE vp.stream_id IN (:streamIds)",
        {
          streamIds = { value = arrayToList( variables.createdStreamIds ), cfsqltype = "cf_sql_integer", list = true }
        },
        { datasource = "fpw" }
      );
      queryExecute(
        "DELETE vr
         FROM voyage_reactions vr
         INNER JOIN voyage_posts vp ON vp.id = vr.post_id
         WHERE vp.stream_id IN (:streamIds)",
        {
          streamIds = { value = arrayToList( variables.createdStreamIds ), cfsqltype = "cf_sql_integer", list = true }
        },
        { datasource = "fpw" }
      );
      queryExecute(
        "DELETE FROM voyage_posts WHERE stream_id IN (:streamIds)",
        {
          streamIds = { value = arrayToList( variables.createdStreamIds ), cfsqltype = "cf_sql_integer", list = true }
        },
        { datasource = "fpw" }
      );
      queryExecute(
        "DELETE FROM voyage_followers WHERE stream_id IN (:streamIds)",
        {
          streamIds = { value = arrayToList( variables.createdStreamIds ), cfsqltype = "cf_sql_integer", list = true }
        },
        { datasource = "fpw" }
      );
      queryExecute(
        "DELETE FROM voyage_streams WHERE id IN (:streamIds)",
        {
          streamIds = { value = arrayToList( variables.createdStreamIds ), cfsqltype = "cf_sql_integer", list = true }
        },
        { datasource = "fpw" }
      );
    }

    if ( arrayLen( variables.createdUserIds ) ) {
      queryExecute(
        "DELETE FROM member_entitlements WHERE user_id IN (:userIds)",
        {
          userIds = { value = arrayToList( variables.createdUserIds ), cfsqltype = "cf_sql_integer", list = true }
        },
        { datasource = "fpw" }
      );
    }

    variables.createdStreamIds = [];
    variables.createdUserIds = [];
  }

}
