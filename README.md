**Moonlake Readme**
**Plugin Architecture**

This plugin uses standard **EditorPlugin** tool for the Moonlake plugin. The plugin allows you to generate meshes from prompts and see them in a grid.

The main Implementation is in **impl.gd**, we use standard Godot classes and signals for the FAL.ai generators to encapsulate how they work (polling). We use these to generate a 3d mesh and then save them to res://ai_generated_assets for future use.

  **Setup UI:**

1.  We generate the dock ui imperatively in [setup_ui@impl.gd]
2.  We instantiate the generators and plug into signals
3.  We then check the res:// folders metdata.json, if found we use that to generate the “Generated Assets” grid.

**Basic Prompt Flow:**

1.  When you press “Generate 3d Asset” it calls [**_on_generate_pressed@impl.md**]
2.  Since this is basic flow it calls [**generate_image@image_gen.gd**]
3.  generate_image will call signals [**_on_image_generated@image_gen.gd**] or [**_on_image_gen_failed@image_gen.gd**] depending on result (it keeps polling every 2 secs to check for status and result)
4.  If image was generated we then pass image data (packed array) to the [**generate_mesh@mesh_gen.md**]
5.  generate mesh will call signals [**_on_mesh_generated@mesh_gen.gd**] or [**_on_mesh_gen_failed@mesh_gen.gd**] depending on result.
6.  if the mesh generation was successful we parse the json and save the assets info in [**metadata.json**] which is picked up by the Asset Grid
7.  Drag and drop a 3d model from the grid to scene to inspect and profit!

**Selected Image Flow:**
1.  You select a previously generated image from the dropdown, update the prompt and clicked Generate
2.  We download the image attached to the selection.
3.  On download finish we do steps 4-7 from the basic flow to generate the 3d asset

**Drawn Image Flow:**
1.  You draw a thing in the canvas clicked Generate
2.  We generate a base64 representation of it and pass it to generate mesh.
3.  On finish we do steps 5-7 from the basic flow to generate the 3d asset

**Generated Assets Grid:**
The grid uses metadata.json to generate a list of files -- it uses the thumbnail image as the placeholder in the grid. Each item is ref counted so no leaks and is of class DraggableAsset. It supports drag/drop of 3d objects to scene
  
**Plugin Structure**
```
Plugin EntryPoint - **plugin.gd**
Plugin Scene Description - **asset-dock.tscn**
Main Plugin Body - **impl.gd**
Helpers:
class **ImageGenerator** - encapsulates nano banana api behaviour (callbacks and polling)
class **MeshGenerator** - encapsulates trellis api behaviour (callbacks and polling)
class **DraggableAsset** - Each item we generate is shown in the UI as a draggable asset
class **DrawingCanvas** - based on gd_paint, this allows you to draw in the dock (input prompt image)

asset_metadata = {
		"id": asset_id,					// locally generated from time
		"prompt": prompt,				// prompt that was used
		"image_url": image_url,				// image used for input
		"thumbnail": "thumb_" + asset_id + ".png",	// thumbnail (its the same image asset)
		"mesh_file": mesh_filename,			// generated mesh file
		"mesh_url": mesh_url,				// url we downloaded it from
		"created_at": timestamp				// creation
	}
```
**What Works:**
1.  Plugin shows proper dock on right sidebar
2.  You will see a textbox to enter prompt
3.  Clicking Generate should upload the prompt and generate a 3d mesh - after generate finishes (see console log or status text) - the 3d mesh will be shown in the dock under the Generated Assets section
4.  Drag the generated image from the dock to the 3d scene to see the model live
5.  You have two options for more control
	1.  Use the canvas to draw the image and add a text prompt (drawing has highest priority)
	2.  Choose an existing generated image and add a text prompt

**What doesn't work**
1.  Abort  - no cancel or abort support - you’ll have to wait until the generation finishes to start another
2.  Dock UX could use some love to make it more manageable with large number of assets
3.  Currently you need to Alt-Tab back after models are generated so that Godot can auto generate the required data from the new models (its supposed to be automatic but I noticed it sometimes doesn’t happen until alt tab back in)
4. Canvas is very limited, check gd_paint for a paint tool that can be incorporated in the plugin
5. Deleting assets outside of the editor crashes the plugin, reload the plugin as a workaround
