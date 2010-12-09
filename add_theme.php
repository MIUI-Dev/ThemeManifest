<?php

function generatePreviews($theme_zip, $theme_path) {
    $files = array();

    for($i = 0; $i < $theme_zip->numFiles; $i++) {
      $entry = $theme_zip->getNameIndex($i);
      $pos = strpos($entry, "preview/");

      if ($pos !== false) {
        $files[] = $entry;
      }
    }
    
    $preview_images = array();
    
    for ($i = 1; $i < sizeof($files); ++$i) {
        // Use regex to account for Windows Thumbs.db and other nonsense files
        if (preg_match('/^.+\.((jpg)|(png))$/i', $files[$i])) {
            $image = $theme_zip->getFromName($files[$i]);

            $thumbnail = new Imagick();
            $thumbnail->readImageBlob($image);
            $thumbnail->thumbnailImage(0, 333);
            $thumbnail->setImageFormat('jpg');

            $thumbnail_filename = $theme_path . "/" . $i . ".jpg";
            $preview_images[] = $thumbnail_filename;

            $thumbnail->writeImage($thumbnail_filename);

            if ($i === 1) {
                $thumbnail->thumbnailImage(0, 167);
                $thumbnail->writeImage($theme_path . "/" . $theme_path . "_thumbnail.jpg");
            }

            $thumbnail->clear();
            $thumbnail->destroy();
        }
    }
    
    return $preview_images;

}

$uploaded_file = $_FILES['uploadedfile']['tmp_name'];
$uploaded_file_name = $_FILES["uploadedfile"]["name"];
$theme_zip = new ZipArchive;

if ($theme_zip->open($uploaded_file) === TRUE) {
    $theme_info = new SimpleXMLElement($theme_zip->getFromName('description.xml'));
    $theme_name = $theme_info->title[0];
    $theme_author = $theme_info->author[0];
    $theme_version = $theme_info->version[0];
    $theme_size = filesize($uploaded_file);

    // Replace spaces with "_" in theme name for theme path
    $theme_path = str_replace(" ", "_", $theme_name);
    if (!file_exists($theme_path)) {
        mkdir($theme_path);
    }
    
    $preview_images = generatePreviews($theme_zip, $theme_path);

    $theme_zip->close();
    
    move_uploaded_file($uploaded_file, "$theme_path/$uploaded_file_name");

    echo "<pre>";
    echo "Add the following code to the proper manifest file:\n\n";
    echo "  {\n\n";
    echo "    \"theme_name\": \"$theme_name\",\n";
    echo "    \"theme_url\": \"http://downloads.miui-themes.com/$theme_path/$uploaded_file_name\",\n";
    echo "    \"theme_author\": \"$theme_author\",\n";
    echo "    \"theme_preview_url\": \"http://downloads.miui-themes.com/$theme_path/$theme_path" . "_thumbnail.jpg\",\n";
    echo "    \"theme_size\": \"" . $theme_size . "\",\n";
    echo "    \"theme_version\": \"$theme_version\",\n";
    echo "    \"theme_screenshot_urls\": [\n";

    for ($i = 0; $i < sizeof($preview_images); ++$i) {
        echo "                               \"http://downloads.miui-themes.com/$theme_path/$preview_images[$i]\"";
        if (($i + 1) !== sizeof($preview_images)) {
            echo ",";
        }
        echo "\n";
    }

    echo "                             ]\n\n";
    echo "  },";
    echo "</pre>";
} else {
    echo "failed to open $uploaded_file_name";
}

?>