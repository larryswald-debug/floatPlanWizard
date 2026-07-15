<cfcomponent output="false">

  <cffunction name="init" access="public" returntype="any" output="false">
    <cfargument name="datasource" type="string" required="false" default="fpw">
    <cfscript>
      variables.datasource = len(trim(arguments.datasource)) ? trim(arguments.datasource) : "fpw";
      return this;
    </cfscript>
  </cffunction>

  <cffunction name="saveUploadedVesselImage" access="public" returntype="struct" output="false">
    <cfargument name="vesselId" type="numeric" required="true">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="uploadPath" type="string" required="true">
    <cfargument name="originalFileName" type="string" required="true">
    <cfargument name="basePath" type="string" required="false" default="">
    <cfscript>
      var out = {
        "SUCCESS" = false,
        "MESSAGE" = "Unable to save vessel image.",
        "IMAGE" = {}
      };
      var qVessel = queryNew("");
      var qExisting = queryNew("");
      var ext = lCase(trim(listLast(arguments.originalFileName, ".")));
      var vesselImageRoot = "";
      var userImageRoot = "";
      var imageRoot = "";
      var fileKey = "";
      var fileName = "";
      var thumbnailFileName = "";
      var sourcePath = "";
      var thumbnailPath = "";
      var sourceRelPath = "";
      var thumbnailRelPath = "";
      var mimeType = "";
      var imageObject = "";

      if (arguments.vesselId LTE 0 OR arguments.userId LTE 0) {
        out.MESSAGE = "A valid vessel and member are required.";
        return out;
      }
      if (!listFindNoCase("jpg,jpeg,png,webp", ext)) {
        out.MESSAGE = "Only JPG, PNG, and WebP images are allowed.";
        return out;
      }
      if (!fileExists(arguments.uploadPath)) {
        out.MESSAGE = "The uploaded image was not found.";
        return out;
      }

      qVessel = queryExecute(
        "SELECT vesselID, vesselName
         FROM vessels
         WHERE vesselID = :vesselId
           AND CAST(userId AS CHAR) = :userId
         LIMIT 1",
        {
          vesselId = { value = val(arguments.vesselId), cfsqltype = "cf_sql_integer" },
          userId = { value = toString(val(arguments.userId)), cfsqltype = "cf_sql_varchar" }
        },
        { datasource = variables.datasource }
      );
      if (qVessel.recordCount EQ 0) {
        out.MESSAGE = "Vessel not found or not owned by this member.";
        return out;
      }

      try {
        imageObject = imageRead(arguments.uploadPath);
      } catch (any invalidImage) {
        out.MESSAGE = "The uploaded file could not be read as an image.";
        return out;
      }

      qExisting = queryExecute(
        "SELECT local_image_path, thumbnail_image_path
         FROM vessel_images
         WHERE vessel_id = :vesselId
         LIMIT 1",
        {
          vesselId = { value = val(arguments.vesselId), cfsqltype = "cf_sql_integer" }
        },
        { datasource = variables.datasource }
      );

      vesselImageRoot = getVesselImageRootPath();
      userImageRoot = joinPath(vesselImageRoot, toString(val(arguments.userId)));
      imageRoot = getVesselImageDirectory(arguments.userId, arguments.vesselId);
      ensureDirectory(vesselImageRoot);
      ensureDirectory(userImageRoot);
      ensureDirectory(imageRoot);
      fileKey = "vessel-" & dateTimeFormat(now(), "yyyymmddHHnnss") & "-" & lCase(left(replace(createUUID(), "-", "", "all"), 12));
      fileName = fileKey & "." & ext;
      thumbnailFileName = fileKey & "-thumb." & ext;
      sourcePath = joinPath(imageRoot, fileName);
      thumbnailPath = joinPath(imageRoot, thumbnailFileName);
      sourceRelPath = "assets/uploads/vessels/" & val(arguments.userId) & "/" & val(arguments.vesselId) & "/" & fileName;
      thumbnailRelPath = "assets/uploads/vessels/" & val(arguments.userId) & "/" & val(arguments.vesselId) & "/" & thumbnailFileName;
      mimeType = mimeTypeFromExtension(ext);

      try {
        fileCopy(arguments.uploadPath, sourcePath);
        generateThumbnail(sourcePath, thumbnailPath);
      } catch (any fileError) {
        safeDeleteFile(sourcePath);
        safeDeleteFile(thumbnailPath);
        out.MESSAGE = "The image could not be stored.";
        return out;
      }

      try {
        queryExecute(
          "INSERT INTO vessel_images (
             vessel_id, local_image_path, thumbnail_image_path, original_filename, mime_type
           ) VALUES (
             :vesselId, :localImagePath, :thumbnailImagePath, :originalFilename, :mimeType
           )
           ON DUPLICATE KEY UPDATE
             local_image_path = VALUES(local_image_path),
             thumbnail_image_path = VALUES(thumbnail_image_path),
             original_filename = VALUES(original_filename),
             mime_type = VALUES(mime_type)",
          {
            vesselId = { value = val(arguments.vesselId), cfsqltype = "cf_sql_integer" },
            localImagePath = { value = sourceRelPath, cfsqltype = "cf_sql_varchar" },
            thumbnailImagePath = { value = thumbnailRelPath, cfsqltype = "cf_sql_varchar" },
            originalFilename = { value = left(trim(arguments.originalFileName), 255), cfsqltype = "cf_sql_varchar" },
            mimeType = { value = mimeType, cfsqltype = "cf_sql_varchar" }
          },
          { datasource = variables.datasource }
        );
      } catch (any databaseError) {
        safeDeleteFile(sourcePath);
        safeDeleteFile(thumbnailPath);
        out.MESSAGE = "The image metadata could not be saved.";
        return out;
      }

      if (qExisting.recordCount GT 0) {
        safeDeleteRelativeFile(qExisting.local_image_path[1], sourceRelPath);
        safeDeleteRelativeFile(qExisting.thumbnail_image_path[1], thumbnailRelPath);
      }

      out.SUCCESS = true;
      out.MESSAGE = "Vessel image saved.";
      out.IMAGE = buildImageAsset(
        sourceRelPath,
        thumbnailRelPath,
        arguments.originalFileName,
        mimeType,
        arguments.basePath
      );
      return out;
    </cfscript>
  </cffunction>

  <cffunction name="removeVesselImage" access="public" returntype="struct" output="false">
    <cfargument name="vesselId" type="numeric" required="true">
    <cfargument name="userId" type="numeric" required="true">
    <cfscript>
      var out = { "SUCCESS" = false, "MESSAGE" = "Unable to remove vessel image." };
      var qImage = queryNew("");

      qImage = queryExecute(
        "SELECT vi.local_image_path, vi.thumbnail_image_path
         FROM vessel_images vi
         INNER JOIN vessels v ON v.vesselID = vi.vessel_id
         WHERE vi.vessel_id = :vesselId
           AND CAST(v.userId AS CHAR) = :userId
         LIMIT 1",
        {
          vesselId = { value = val(arguments.vesselId), cfsqltype = "cf_sql_integer" },
          userId = { value = toString(val(arguments.userId)), cfsqltype = "cf_sql_varchar" }
        },
        { datasource = variables.datasource }
      );

      if (qImage.recordCount EQ 0) {
        out.SUCCESS = true;
        out.MESSAGE = "No vessel image was set.";
        return out;
      }

      queryExecute(
        "DELETE FROM vessel_images WHERE vessel_id = :vesselId",
        {
          vesselId = { value = val(arguments.vesselId), cfsqltype = "cf_sql_integer" }
        },
        { datasource = variables.datasource }
      );
      safeDeleteRelativeFile(qImage.local_image_path[1], "");
      safeDeleteRelativeFile(qImage.thumbnail_image_path[1], "");
      removeEmptyVesselImageDirectory(arguments.userId, arguments.vesselId);

      out.SUCCESS = true;
      out.MESSAGE = "Vessel image removed.";
      return out;
    </cfscript>
  </cffunction>

  <cffunction name="deleteVesselImageFiles" access="public" returntype="boolean" output="false">
    <cfargument name="vesselId" type="numeric" required="true">
    <cfargument name="userId" type="numeric" required="true">
    <cfscript>
      var imageDirectory = "";
      if (arguments.vesselId LTE 0 OR arguments.userId LTE 0) return false;
      imageDirectory = getVesselImageDirectory(arguments.userId, arguments.vesselId);
      try {
        if (directoryExists(imageDirectory)) {
          directoryDelete(imageDirectory, true);
        }
        return true;
      } catch (any ignored) {
        return false;
      }
    </cfscript>
  </cffunction>

  <cffunction name="buildImageAsset" access="public" returntype="struct" output="false">
    <cfargument name="localImagePath" required="false" default="">
    <cfargument name="thumbnailImagePath" required="false" default="">
    <cfargument name="originalFileName" required="false" default="">
    <cfargument name="mimeType" required="false" default="">
    <cfargument name="basePath" type="string" required="false" default="">
    <cfscript>
      var sourceRel = normalizeVesselImageRelativePath(arguments.localImagePath);
      var thumbnailRel = normalizeVesselImageRelativePath(arguments.thumbnailImagePath);
      var sourcePath = len(sourceRel) ? joinPath(getRepoRootPath(), sourceRel) : "";
      var thumbnailPath = len(thumbnailRel) ? joinPath(getRepoRootPath(), thumbnailRel) : "";
      var cleanBasePath = normalizeBasePath(arguments.basePath);
      var out = {
        "hasImage" = false,
        "sourceUrl" = "",
        "thumbnailUrl" = "",
        "originalFileName" = safeString(arguments.originalFileName),
        "mimeType" = safeString(arguments.mimeType)
      };

      if (len(sourceRel) AND fileExists(sourcePath)) {
        out.hasImage = true;
        out.sourceUrl = imageUrlWithVersion(cleanBasePath & "/" & sourceRel, sourcePath);
      }
      if (len(thumbnailRel) AND fileExists(thumbnailPath)) {
        out.thumbnailUrl = imageUrlWithVersion(cleanBasePath & "/" & thumbnailRel, thumbnailPath);
      }
      if (out.hasImage AND !len(out.thumbnailUrl)) {
        out.thumbnailUrl = out.sourceUrl;
      }
      return out;
    </cfscript>
  </cffunction>

  <cffunction name="generateThumbnail" access="private" returntype="void" output="false">
    <cfargument name="sourcePath" type="string" required="true">
    <cfargument name="thumbnailPath" type="string" required="true">
    <cfscript>
      var thumbnailImage = imageRead(arguments.sourcePath);
      imageScaleToFit(thumbnailImage, 480, 320);
      if (fileExists(arguments.thumbnailPath)) {
        fileDelete(arguments.thumbnailPath);
      }
      imageWrite(thumbnailImage, arguments.thumbnailPath);
    </cfscript>
  </cffunction>

  <cffunction name="getVesselImageDirectory" access="private" returntype="string" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="vesselId" type="numeric" required="true">
    <cfscript>
      return joinPath(
        joinPath(getVesselImageRootPath(), toString(val(arguments.userId))),
        toString(val(arguments.vesselId))
      );
    </cfscript>
  </cffunction>

  <cffunction name="getVesselImageRootPath" access="private" returntype="string" output="false">
    <cfscript>
      return joinPath(getRepoRootPath(), "assets/uploads/vessels");
    </cfscript>
  </cffunction>

  <cffunction name="getRepoRootPath" access="private" returntype="string" output="false">
    <cfscript>
      return getDirectoryFromPath(getCurrentTemplatePath()) & "../../";
    </cfscript>
  </cffunction>

  <cffunction name="normalizeVesselImageRelativePath" access="private" returntype="string" output="false">
    <cfargument name="value" required="false" default="">
    <cfscript>
      var relativePath = replace(safeString(arguments.value), "\\", "/", "all");
      relativePath = reReplace(relativePath, "^/+", "", "all");
      if (!len(relativePath) OR find("..", relativePath)) return "";
      if (findNoCase("assets/uploads/vessels/", relativePath) NEQ 1) return "";
      return relativePath;
    </cfscript>
  </cffunction>

  <cffunction name="safeDeleteRelativeFile" access="private" returntype="void" output="false">
    <cfargument name="relativePath" required="false" default="">
    <cfargument name="keepRelativePath" required="false" default="">
    <cfscript>
      var cleanRelativePath = normalizeVesselImageRelativePath(arguments.relativePath);
      var keepPath = normalizeVesselImageRelativePath(arguments.keepRelativePath);
      var fullPath = "";
      if (!len(cleanRelativePath) OR (len(keepPath) AND compareNoCase(cleanRelativePath, keepPath) EQ 0)) return;
      fullPath = joinPath(getRepoRootPath(), cleanRelativePath);
      safeDeleteFile(fullPath);
    </cfscript>
  </cffunction>

  <cffunction name="safeDeleteFile" access="private" returntype="void" output="false">
    <cfargument name="path" type="string" required="true">
    <cfscript>
      try {
        if (len(trim(arguments.path)) AND fileExists(arguments.path)) {
          fileDelete(arguments.path);
        }
      } catch (any ignored) {
      }
    </cfscript>
  </cffunction>

  <cffunction name="removeEmptyVesselImageDirectory" access="private" returntype="void" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="vesselId" type="numeric" required="true">
    <cfscript>
      var imageDirectory = getVesselImageDirectory(arguments.userId, arguments.vesselId);
      try {
        if (directoryExists(imageDirectory) AND arrayLen(directoryList(imageDirectory, false, "array")) EQ 0) {
          directoryDelete(imageDirectory);
        }
      } catch (any ignored) {
      }
    </cfscript>
  </cffunction>

  <cffunction name="ensureDirectory" access="private" returntype="void" output="false">
    <cfargument name="path" type="string" required="true">
    <cfscript>
      if (!directoryExists(arguments.path)) {
        directoryCreate(arguments.path);
      }
    </cfscript>
  </cffunction>

  <cffunction name="mimeTypeFromExtension" access="private" returntype="string" output="false">
    <cfargument name="extension" type="string" required="true">
    <cfscript>
      var ext = lCase(trim(arguments.extension));
      if (ext EQ "png") return "image/png";
      if (ext EQ "webp") return "image/webp";
      return "image/jpeg";
    </cfscript>
  </cffunction>

  <cffunction name="imageUrlWithVersion" access="private" returntype="string" output="false">
    <cfargument name="url" type="string" required="true">
    <cfargument name="path" type="string" required="true">
    <cfscript>
      var modified = "";
      try {
        modified = getFileInfo(arguments.path).lastModified;
        return arguments.url & "?v=" & dateFormat(modified, "yyyymmdd") & timeFormat(modified, "HHmmss");
      } catch (any ignored) {
        return arguments.url;
      }
    </cfscript>
  </cffunction>

  <cffunction name="normalizeBasePath" access="private" returntype="string" output="false">
    <cfargument name="value" type="string" required="false" default="">
    <cfscript>
      var basePath = trim(arguments.value);
      var scriptName = structKeyExists(cgi, "script_name") ? toString(cgi.script_name) : "";
      var markerPosition = 0;
      if (!len(basePath)) {
        markerPosition = findNoCase("/api/v1/", scriptName);
        if (markerPosition GT 1) {
          basePath = left(scriptName, markerPosition - 1);
        }
      }
      basePath = reReplace(basePath, "/+$", "", "all");
      if (basePath EQ "/") return "";
      return basePath;
    </cfscript>
  </cffunction>

  <cffunction name="normalizeFilesystemPath" access="private" returntype="string" output="false">
    <cfargument name="path" type="string" required="true">
    <cfscript>
      return replace(arguments.path, "\", "/", "all");
    </cfscript>
  </cffunction>

  <cffunction name="joinPath" access="private" returntype="string" output="false">
    <cfargument name="leftPath" type="string" required="true">
    <cfargument name="rightPath" type="string" required="true">
    <cfscript>
      return reReplace(normalizeFilesystemPath(arguments.leftPath), "/+$", "", "all")
        & "/"
        & reReplace(normalizeFilesystemPath(arguments.rightPath), "^/+", "", "all");
    </cfscript>
  </cffunction>

  <cffunction name="safeString" access="private" returntype="string" output="false">
    <cfargument name="value" required="false" default="">
    <cfscript>
      if (isNull(arguments.value)) return "";
      return trim(toString(arguments.value));
    </cfscript>
  </cffunction>

</cfcomponent>

