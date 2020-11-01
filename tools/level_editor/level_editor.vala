/*
 * Copyright (c) 2012-2020 Daniele Bartolini and individual contributors.
 * License: https://github.com/dbartolini/crown/blob/master/LICENSE
 */

using Gdk; // Pixbuf
using Gee;
using Gtk;

namespace Crown
{
const int WINDOW_DEFAULT_WIDTH = 1280;
const int WINDOW_DEFAULT_HEIGHT = 720;

public class LevelEditorWindow : Gtk.ApplicationWindow
{
	private const GLib.ActionEntry[] action_entries =
	{
		{ "fullscreen", on_fullscreen, null, null }
	};

	public bool _fullscreen;

	public LevelEditorWindow(Gtk.Application app)
	{
		Object(application: app);

		this.add_action_entries(action_entries, this);

		this.title = "Level Editor";
		this.key_press_event.connect(this.on_key_press);
		this.key_release_event.connect(this.on_key_release);
		this.window_state_event.connect(this.on_window_state_event);
		this.delete_event.connect(this.on_delete_event);
		this.focus_out_event.connect(this.on_focus_out);

		_fullscreen = false;
	}

	private void on_fullscreen(GLib.SimpleAction action, GLib.Variant? param)
	{
		if (_fullscreen)
			unfullscreen();
		else
			fullscreen();
	}

	private bool on_key_press(Gdk.EventKey ev)
	{
		LevelEditorApplication app = (LevelEditorApplication)application;

		if (ev.keyval == Gdk.Key.Control_L)
			app._editor.send_script(LevelEditorApi.key_down("ctrl_left"));
		else if (ev.keyval == Gdk.Key.Shift_L)
			app._editor.send_script(LevelEditorApi.key_down("shift_left"));
		else if (ev.keyval == Gdk.Key.Alt_L)
			app._editor.send_script(LevelEditorApi.key_down("alt_left"));

		return Gdk.EVENT_PROPAGATE;
	}

	private bool on_key_release(Gdk.EventKey ev)
	{
		LevelEditorApplication app = (LevelEditorApplication)application;

		if (ev.keyval == Gdk.Key.Control_L)
			app._editor.send_script(LevelEditorApi.key_up("ctrl_left"));
		else if (ev.keyval == Gdk.Key.Shift_L)
			app._editor.send_script(LevelEditorApi.key_up("shift_left"));
		else if (ev.keyval == Gdk.Key.Alt_L)
			app._editor.send_script(LevelEditorApi.key_up("alt_left"));

		return Gdk.EVENT_PROPAGATE;
	}

	private bool on_window_state_event(Gdk.EventWindowState ev)
	{
		_fullscreen = (ev.new_window_state & Gdk.WindowState.FULLSCREEN) != 0;
		return Gdk.EVENT_STOP;
	}

	private bool on_delete_event()
	{
		LevelEditorApplication app = (LevelEditorApplication)application;
		if (app.should_quit())
		{
			app.close_all();
			return Gdk.EVENT_PROPAGATE; // Quit application
		}

		return Gdk.EVENT_STOP; // Keep alive
	}

	private bool on_focus_out(Gdk.EventFocus ev)
	{
		LevelEditorApplication app = (LevelEditorApplication)application;

		app._editor.send_script(LevelEditorApi.key_up("ctrl_left"));
		app._editor.send_script(LevelEditorApi.key_up("shift_left"));
		app._editor.send_script(LevelEditorApi.key_up("alt_left"));
		return Gdk.EVENT_PROPAGATE;
	}
}

public enum StartGame
{
	NORMAL,
	TEST
}

public class LevelEditorApplication : Gtk.Application
{
	// Constants
	private const GLib.ActionEntry[] action_entries_file =
	{
		//                                 parameter type
		// name           activate()       |     state
		// |              |                |     |
		{ "menu-file",    null,            null, null },
		{ "new-level",    on_new_level,    null, null },
		{ "open-level",   on_open_level,   "s",  null },
		{ "new-project",  on_new_project,  null, null },
		{ "open-project", on_open_project, null, null },
		{ "save",         on_save,         null, null },
		{ "save-as",      on_save_as,      null, null },
		{ "import",       on_import,       null, null },
		{ "preferences",  on_preferences,  null, null },
		{ "deploy",       on_deploy,       null, null },
		{ "close",        on_close,        null, null },
		{ "quit",         on_quit,         null, null }
	};

	private const GLib.ActionEntry[] action_entries_edit =
	{
		{ "menu-edit",            null,                        null, null         },
		{ "undo",                 on_undo,                     null, null         },
		{ "redo",                 on_redo,                     null, null         },
		{ "duplicate",            on_duplicate,                null, null         },
		{ "delete",               on_delete,                   null, null         },
		{ "tool",                 on_tool_changed,             "s",  "'move'"     },
		{ "snap",                 on_snap_mode_changed,        "s",  "'relative'" },
		{ "reference-system",     on_reference_system_changed, "s",  "'local'"    },
		{ "snap-to-grid",         on_snap_to_grid,             null, "true"       },
		{ "menu-grid",            null,                        null, null         },
		{ "grid-show",            on_show_grid,                null, "true"       },
		{ "grid-custom",          on_custom_grid,              null, null         },
		{ "grid-preset",          on_grid_changed,             "s",  "'1'"        },
		{ "menu-rotation-snap",   null,                        null, null         },
		{ "rotation-snap-custom", on_rotation_snap,            null, null         },
		{ "rotation-snap-preset", on_rotation_snap_changed,    "s",  "'15'"       }
	};

	private const GLib.ActionEntry[] action_entries_create =
	{
		{ "menu-create",        null,                null, null },
		{ "menu-primitives",    null,                null, null },
		{ "primitive-cube",     on_create_primitive, null, null },
		{ "primitive-sphere",   on_create_primitive, null, null },
		{ "primitive-cone",     on_create_primitive, null, null },
		{ "primitive-cylinder", on_create_primitive, null, null },
		{ "primitive-plane",    on_create_primitive, null, null },
		{ "camera",             on_create_primitive, null, null },
		{ "light",              on_create_primitive, null, null },
		{ "sound-source",       on_create_primitive, null, null }
	};

	private const GLib.ActionEntry[] action_entries_camera =
	{
		{ "menu-camera", null,           null, null            },
		{ "camera-view", on_camera_view, "s",  "'perspective'" }
	};

	private const GLib.ActionEntry[] action_entries_view =
	{
		{ "menu-view",           null,                   null, null    },
		{ "resource-chooser",    on_resource_chooser,    null, null    },
		{ "project-browser",     on_project_browser,     null, null    },
		{ "console",             on_console,             null, null    },
		{ "statusbar",           on_statusbar,           null, null    },
		{ "inspector",           on_inspector,           null, null    },
		{ "debug-render-world",  on_debug_render_world,  null, "false" },
		{ "debug-physics-world", on_debug_physics_world, null, "false" }
	};

	private const GLib.ActionEntry[] action_entries_debug =
	{
		{ "menu-debug",          null,                   null, null },
		{ "test-level",          on_run_game,            null, null },
		{ "run-game",            on_run_game,            null, null },
		{ "build-data",          on_build_data,          null, null },
		{ "reload-lua",          on_refresh_lua,         null, null },
		{ "restart-editor-view", on_restart_editor_view, null, null }
	};

	private const GLib.ActionEntry[] action_entries_help =
	{
		{ "menu-help",    null,            null, null },
		{ "manual",       on_manual,       null, null },
		{ "report-issue", on_report_issue, null, null },
		{ "browse-logs",  on_browse_logs,  null, null },
		{ "changelog",    on_changelog,    null, null },
		{ "about",        on_about,        null, null }
	};

	// Command line options
	private string? _source_dir = null;
	private string _level_resource = "";
	private User _user;

	// Editor state
	private double _grid_size;
	private double _rotation_snap;
	private bool _show_grid;
	private bool _snap_to_grid;
	private bool _debug_render_world;
	private bool _debug_physics_world;
	private LevelEditorApi.ToolType _tool_type;
	private LevelEditorApi.ToolType _tool_type_prev;
	private LevelEditorApi.SnapMode _snap_mode;
	private LevelEditorApi.ReferenceSystem _reference_system;

	// Project state
	private string _placeable_type;
	private string _placeable_name;

	// Accelerators
	private string[] _tool_place_accels;
	private string[] _tool_move_accels;
	private string[] _tool_rotate_accels;
	private string[] _tool_scale_accels;
	private string[] _camera_view_perspective_accels;
	private string[] _camera_view_front_accels;
	private string[] _camera_view_back_accels;
	private string[] _camera_view_right_accels;
	private string[] _camera_view_left_accels;
	private string[] _camera_view_top_accels;
	private string[] _camera_view_bottom_accels;

	// Engine connections
	private GLib.Subprocess _compiler_process;
	private GLib.Subprocess _editor_process;
	private GLib.Subprocess _game_process;
	private ConsoleClient _compiler;
	public ConsoleClient _editor;
	private ConsoleClient _game;

	// Level data
	private Database _database;
	private Project _project;
	private ProjectStore _project_store;
	private Level _level;
	private DataCompiler _data_compiler;

	// Widgets
	private ProjectBrowser _project_browser;
	private EditorView _editor_view;
	private LevelTreeView _level_treeview;
	private LevelLayersTreeView _level_layers_treeview;
	private PropertiesView _properties_view;
	private PreferencesDialog _preferences_dialog;
	private ResourceChooser _resource_chooser;
	private Gtk.Popover _resource_popover;
	private Gtk.Overlay _editor_view_overlay;
	private Slide _project_slide;
	private Slide _editor_slide;
	private Slide _inspector_slide;

	private Gtk.Toolbar _toolbar;
	private Gtk.ToolButton _toolbar_run;
	private Gtk.Notebook _level_tree_view_notebook;
	private Gtk.Paned _editor_pane;
	private Gtk.Paned _content_pane;
	private Gtk.Paned _inspector_pane;
	private Gtk.Paned _main_pane;
	private Statusbar _statusbar;
	private Gtk.Box _main_vbox;
	private Gtk.FileFilter _file_filter;
	private Gtk.ComboBoxText _combo;
	private PanelNewProject _panel_new_project;
	private PanelProjectsList _panel_projects_list;
	private PanelWelcome _panel_welcome;
	private Gtk.Stack _main_stack;

	private uint _save_timer_id;

	public LevelEditorApplication()
	{
		Object(application_id: "org.crown.level_editor"
			, flags: GLib.ApplicationFlags.FLAGS_NONE
			);
	}

	protected override void startup()
	{
		base.startup();

		Intl.setlocale(LocaleCategory.ALL, "C");
		Gtk.Settings.get_default().gtk_theme_name = "Adwaita";
		Gtk.Settings.get_default().gtk_application_prefer_dark_theme = true;

		Gtk.CssProvider provider = new Gtk.CssProvider();
		Gdk.Screen screen = Gdk.Display.get_default().get_default_screen();
		Gtk.StyleContext.add_provider_for_screen(screen, provider, STYLE_PROVIDER_PRIORITY_APPLICATION);
		provider.load_from_resource("/org/crown/level_editor/css/style.css");

		// HACK: register CrownClamp type within GObject's type system to
		// make GtkBuilder able to find it when creating the widget from
		// .ui files.
		// https://stackoverflow.com/questions/24235937/custom-gtk-widget-with-template-ui
		new Clamp().get_type().ensure();

		this.add_action_entries(action_entries_file, this);
		this.add_action_entries(action_entries_edit, this);
		this.add_action_entries(action_entries_create, this);
		this.add_action_entries(action_entries_camera, this);
		this.add_action_entries(action_entries_view, this);
		this.add_action_entries(action_entries_debug, this);
		this.add_action_entries(action_entries_help, this);

		_tool_place_accels = this.get_accels_for_action("app.tool::place");
		_tool_move_accels = this.get_accels_for_action("app.tool::move");
		_tool_rotate_accels = this.get_accels_for_action("app.tool::rotate");
		_tool_scale_accels = this.get_accels_for_action("app.tool::scale");
		_camera_view_perspective_accels = this.get_accels_for_action("app.camera-view::perspective");
		_camera_view_front_accels = this.get_accels_for_action("app.camera-view::front");
		_camera_view_back_accels = this.get_accels_for_action("app.camera-view::back");
		_camera_view_right_accels = this.get_accels_for_action("app.camera-view::right");
		_camera_view_left_accels = this.get_accels_for_action("app.camera-view::left");
		_camera_view_top_accels = this.get_accels_for_action("app.camera-view::top");
		_camera_view_bottom_accels = this.get_accels_for_action("app.camera-view::bottom");

		_compiler = new ConsoleClient();
		_compiler.connected.connect(on_compiler_connected);
		_compiler.disconnected.connect(on_compiler_disconnected_unexpected);
		_compiler.message_received.connect(on_message_received);

		_data_compiler = new DataCompiler(_compiler);

		_project = new Project(_data_compiler);
		_project.set_toolchain_dir(_toolchain_dir.get_path());

		_database = new Database();

		_editor = new ConsoleClient();
		_editor.connected.connect(on_editor_connected);
		_editor.disconnected.connect(on_editor_disconnected_unexpected);
		_editor.message_received.connect(on_message_received);

		_game = new ConsoleClient();
		_game.connected.connect(on_game_connected);
		_game.disconnected.connect(on_game_disconnected);
		_game.message_received.connect(on_message_received);

		_level = new Level(_database, _editor, _project);

		// Editor state
		_grid_size = 1.0;
		_rotation_snap = 15.0;
		_show_grid = true;
		_snap_to_grid = true;
		_debug_render_world = false;
		_debug_physics_world = false;
		_tool_type = LevelEditorApi.ToolType.MOVE;
		_tool_type_prev = _tool_type;
		_snap_mode = LevelEditorApi.SnapMode.RELATIVE;
		_reference_system = LevelEditorApi.ReferenceSystem.LOCAL;

		// Project state
		_placeable_type = "";
		_placeable_name = "";

		// Engine connections
		_compiler_process = null;
		_editor_process = null;
		_game_process = null;

		_project_store = new ProjectStore(_project);

		// Widgets
		_combo = new Gtk.ComboBoxText();
		_combo.append("editor", "Editor");
		_combo.append("game", "Game");
		_combo.set_active_id("editor");

		_console_view = new ConsoleView(_project, _combo);
		_project_browser = new ProjectBrowser(_project, _project_store);
		_level_treeview = new LevelTreeView(_database, _level);
		_level_layers_treeview = new LevelLayersTreeView(_database, _level);
		_properties_view = new PropertiesView(_level, _project_store);

		_project_slide = new Slide();
		_editor_slide = new Slide();
		_inspector_slide = new Slide();

		Gtk.Builder builder = new Gtk.Builder.from_resource("/org/crown/level_editor/ui/toolbar.ui");
		_toolbar = builder.get_object("toolbar") as Gtk.Toolbar;
		_toolbar_run = builder.get_object("run") as Gtk.ToolButton;

		_editor_view_overlay = new Gtk.Overlay();
		_editor_view_overlay.add_overlay(_toolbar);

		_resource_popover = new Gtk.Popover(_toolbar);
		_resource_popover.delete_event.connect(() => { _resource_popover.hide(); return Gdk.EVENT_STOP; });
		_resource_popover.modal = true;

		_preferences_dialog = new PreferencesDialog(this);
		_preferences_dialog.set_transient_for(this.active_window);
		_preferences_dialog.delete_event.connect(() => { _preferences_dialog.hide(); return Gdk.EVENT_STOP; });

		_resource_chooser = new ResourceChooser(_project, _project_store, true);
		_resource_chooser.resource_selected.connect(on_resource_browser_resource_selected);
		_resource_chooser.resource_selected.connect(() => { _resource_popover.hide(); });
		_resource_popover.add(_resource_chooser);

		_level_tree_view_notebook = new Notebook();
		_level_tree_view_notebook.show_border = false;
		_level_tree_view_notebook.append_page(_level_treeview, new Gtk.Image.from_icon_name("level-tree", IconSize.SMALL_TOOLBAR));
		_level_tree_view_notebook.append_page(_level_layers_treeview, new Gtk.Image.from_icon_name("level-layers", IconSize.SMALL_TOOLBAR));

		_editor_pane = new Gtk.Paned(Gtk.Orientation.HORIZONTAL);
		_editor_pane.pack1(_project_slide, false, false);
		_editor_pane.pack2(_editor_slide, true, false);

		_content_pane = new Gtk.Paned(Gtk.Orientation.VERTICAL);
		_content_pane.pack1(_editor_pane, true, false);
		_content_pane.pack2(_console_view, false, false);

		_inspector_pane = new Gtk.Paned(Gtk.Orientation.VERTICAL);
		_inspector_pane.pack1(_level_tree_view_notebook, true, false);
		_inspector_pane.pack2(_properties_view, false, false);

		_main_pane = new Gtk.Paned(Gtk.Orientation.HORIZONTAL);
		_main_pane.pack1(_content_pane, true, false);
		_main_pane.pack2(_inspector_slide, false, false);

		_statusbar = new Statusbar();

		_main_vbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
		_main_vbox.pack_start(_main_pane, true, true, 0);
		_main_vbox.pack_start(_statusbar, false, false, 0);
		_main_vbox.set_visible(true);

		_file_filter = new Gtk.FileFilter();
		_file_filter.set_filter_name("Level (*.level)");
		_file_filter.add_pattern("*.level");

		_user = new User();
		_panel_new_project = new PanelNewProject(this, _user, _project);
		_panel_new_project.fill_templates_list(_templates_dir.get_path());

		_panel_welcome = new PanelWelcome();
		_panel_projects_list = new PanelProjectsList(this, _user);
		_panel_welcome.pack_start(_panel_projects_list);
		_panel_welcome.set_visible(true); // To make Gtk.Stack work...

		_main_stack = new Gtk.Stack();
		_main_stack.add_named(_panel_welcome, "panel_welcome");
		_main_stack.add_named(_panel_new_project, "panel_new_project");
		_main_stack.add_named(_main_vbox, "main_vbox");

		load_settings();
		_user.load(_user_file.get_path());

		if (_source_dir == null)
		{
			show_panel("panel_welcome");
		}
		else
		{
			show_panel("main_vbox");
			restart_backend(_source_dir, _level_resource);
		}
	}

	public void load_settings()
	{
		Hashtable settings = SJSON.load(_settings_file.get_path());

		_preferences_dialog.load(settings.has_key("preferences") ? (Hashtable)settings["preferences"] : new Hashtable());
	}

	public void save_settings()
	{
		Hashtable preferences = new Hashtable();
		_preferences_dialog.save(preferences);

		Hashtable settings = new Hashtable();
		settings["preferences"] = preferences;

		SJSON.save(settings, _settings_file.get_path());
	}

	protected override void activate()
	{
		if (this.active_window == null)
		{
			LevelEditorWindow win = new LevelEditorWindow(this);
			win.set_default_size(WINDOW_DEFAULT_WIDTH, WINDOW_DEFAULT_HEIGHT);
			win.add(_main_stack);

			try
			{
				win.icon = IconTheme.get_default().load_icon("pepper", 48, 0);
			}
			catch (Error e)
			{
				loge(e.message);
			}
		}

		this.active_window.show_all();
		this.active_window.maximize();
	}

	protected override bool local_command_line(ref unowned string[] args, out int exit_status)
	{
		if (args.length > 1)
		{
			if (!GLib.FileUtils.test(args[1], FileTest.EXISTS) || !GLib.FileUtils.test(args[1], FileTest.IS_DIR))
			{
				loge("Source directory does not exist or it is not a directory");
				exit_status = 1;
				return true;
			}

			_source_dir = args[1];
		}

		if (args.length > 2)
		{
			// Validation is done below after the Project object instantiation
			_level_resource = args[2];
		}

		exit_status = 0;
		return false;
	}

	protected override int command_line(ApplicationCommandLine command_line)
	{
		this.activate();
		return 0;
	}

	public ConsoleClient? current_selected_client()
	{
		if (_combo.get_active_id() == "editor")
			return _editor;
		else if (_combo.get_active_id() == "game")
			return _game;
		else
			return null;
	}

	private void on_resource_browser_resource_selected(string type, string name)
	{
		set_placeable(type, name);
		activate_action("tool", new GLib.Variant.string("place"));
	}

	private void on_compiler_connected(string address, int port)
	{
		logi("Connected to data_compiler@%s:%d".printf(address, port));
		_compiler.receive_async();
	}

	private void on_compiler_disconnected()
	{
		logi("Disconnected from data_compiler");
	}

	private void on_compiler_disconnected_unexpected()
	{
		on_compiler_disconnected();

		stop_game();
		stop_editor();

		// Reset the callback
		_data_compiler.finished(false);

		_project_slide.show_widget(compiler_crashed_label());
		_editor_slide.show_widget(compiler_crashed_label());
		_inspector_slide.show_widget(compiler_crashed_label());
	}

	private void on_editor_connected(string address, int port)
	{
		logi("Connected to level_editor@%s:%d".printf(address, port));
		_editor.receive_async();
	}

	private void on_editor_disconnected()
	{
		logi("Disconnected from editor");
	}

	private void on_editor_disconnected_unexpected()
	{
		on_editor_disconnected();

		Gtk.Label label = new Gtk.Label(null);
		label.set_markup("Something went wrong.\rTry to <a href=\"restart\">restart</a> this view.");
		label.activate_link.connect(() => {
			activate_action("restart-editor-view", null);
			return true;
		});
		_editor_slide.show_widget(label);
	}

	private void on_game_connected(string address, int port)
	{
		logi("Connected to game@%s:%d".printf(address, port));
		_game.receive_async();
		_combo.set_active_id("game");
	}

	private void on_game_disconnected()
	{
		logi("Disconnected from game");
		_project.delete_garbage();
		_combo.set_active_id("editor");
		_toolbar_run.icon_name = "game-run";
	}

	private void on_message_received(ConsoleClient client, uint8[] json)
	{
		Hashtable msg = JSON.decode(json) as Hashtable;
		string msg_type = msg["type"] as string;

		if (msg_type == "message")
		{
			log((string)msg["system"], (string)msg["severity"], (string)msg["message"]);
		}
		else if (msg_type == "add_file")
		{
			string path = (string)msg["path"];

			_project.add_file(path);
		}
		else if (msg_type == "remove_file")
		{
			string path = (string)msg["path"];

			_project.remove_file(path);
		}
		else if (msg_type == "add_tree")
		{
			string path = (string)msg["path"];

			_project.add_tree(path);
		}
		else if (msg_type == "remove_tree")
		{
			string path = (string)msg["path"];

			_project.remove_tree(path);
		}
		else if (msg_type == "compile")
		{
			// Guid id = Guid.parse((string)msg["id"]);

			if (msg.has_key("start"))
			{
				// FIXME
			}
			else if (msg.has_key("success"))
			{
				_data_compiler.finished((bool)msg["success"]);
			}
		}
		else if (msg_type == "unit_spawned")
		{
			string id             = (string)           msg["id"];
			string name           = (string)           msg["name"];
			ArrayList<Value?> pos = (ArrayList<Value?>)msg["position"];
			ArrayList<Value?> rot = (ArrayList<Value?>)msg["rotation"];
			ArrayList<Value?> scl = (ArrayList<Value?>)msg["scale"];

			_level.on_unit_spawned(Guid.parse(id)
				, name
				, Vector3.from_array(pos)
				, Quaternion.from_array(rot)
				, Vector3.from_array(scl)
				);
		}
		else if (msg_type == "sound_spawned")
		{
			string id             = (string)           msg["id"];
			string name           = (string)           msg["name"];
			ArrayList<Value?> pos = (ArrayList<Value?>)msg["position"];
			ArrayList<Value?> rot = (ArrayList<Value?>)msg["rotation"];
			ArrayList<Value?> scl = (ArrayList<Value?>)msg["scale"];
			double range          = (double)           msg["range"];
			double volume         = (double)           msg["volume"];
			bool loop             = (bool)             msg["loop"];

			_level.on_sound_spawned(Guid.parse(id)
				, name
				, Vector3.from_array(pos)
				, Quaternion.from_array(rot)
				, Vector3.from_array(scl)
				, range
				, volume
				, loop
				);
		}
		else if (msg_type == "move_objects")
		{
			Hashtable ids           = (Hashtable)msg["ids"];
			Hashtable new_positions = (Hashtable)msg["new_positions"];
			Hashtable new_rotations = (Hashtable)msg["new_rotations"];
			Hashtable new_scales    = (Hashtable)msg["new_scales"];

			ArrayList<string> keys = new ArrayList<string>.wrap(ids.keys.to_array());
			keys.sort(Gee.Functions.get_compare_func_for(typeof(string)));

			Guid[] n_ids             = new Guid[keys.size];
			Vector3[] n_positions    = new Vector3[keys.size];
			Quaternion[] n_rotations = new Quaternion[keys.size];
			Vector3[] n_scales       = new Vector3[keys.size];

			for (int i = 0; i < keys.size; ++i)
			{
				string k = keys[i];

				n_ids[i]       = Guid.parse((string)ids[k]);
				n_positions[i] = Vector3.from_array((ArrayList<Value?>)(new_positions[k]));
				n_rotations[i] = Quaternion.from_array((ArrayList<Value?>)new_rotations[k]);
				n_scales[i]    = Vector3.from_array((ArrayList<Value?>)new_scales[k]);
			}

			_level.on_move_objects(n_ids, n_positions, n_rotations, n_scales);
		}
		else if (msg_type == "selection")
		{
			Hashtable objects = (Hashtable)msg["objects"];

			ArrayList<string> keys = new ArrayList<string>.wrap(objects.keys.to_array());
			keys.sort(Gee.Functions.get_compare_func_for(typeof(string)));

			Guid[] ids = new Guid[keys.size];

			for (int i = 0; i < keys.size; ++i)
			{
				string k = keys[i];
				ids[i] = Guid.parse((string)objects[k]);
			}

			_level.on_selection(ids);
		}
		else if (msg_type == "error")
		{
			loge((string)msg["message"]);
		}
		else
		{
			loge("Unknown message type: " + msg_type);
		}

		// Receive next message
		client.receive_async();
	}

	private void append_editor_state(StringBuilder sb)
	{
		// This state is common to any project.
		sb.append(LevelEditorApi.set_grid_size(_grid_size));
		sb.append(LevelEditorApi.set_rotation_snap(_rotation_snap));
		sb.append(LevelEditorApi.enable_show_grid(_show_grid));
		sb.append(LevelEditorApi.enable_snap_to_grid(_snap_to_grid));
		sb.append(LevelEditorApi.enable_debug_render_world(_debug_render_world));
		sb.append(LevelEditorApi.enable_debug_physics_world(_debug_physics_world));
		sb.append(LevelEditorApi.set_tool_type(_tool_type));
		sb.append(LevelEditorApi.set_snap_mode(_snap_mode));
		sb.append(LevelEditorApi.set_reference_system(_reference_system));
	}

	private void append_project_state(StringBuilder sb)
	{
		// This state is not guaranteed to be applicable to any project.
		if (_placeable_type != "")
			sb.append(LevelEditorApi.set_placeable(_placeable_type, _placeable_name));
	}

	private void send_state()
	{
		StringBuilder sb = new StringBuilder();
		append_editor_state(sb);
		append_project_state(sb);
		_editor.send_script(sb.str);
	}

	private bool on_button_press(Gdk.EventButton ev)
	{
		return Gdk.EVENT_STOP;
	}

	private bool on_button_release(Gdk.EventButton ev)
	{
		return Gdk.EVENT_STOP;
	}

	Gtk.Widget starting_compiler_label()
	{
		return new Gtk.Label("Compiling resources, please wait...");
	}

	Gtk.Widget compiler_crashed_label()
	{
		Gtk.Label label = new Gtk.Label(null);
		label.set_markup("Data Compiler disconnected.\rTry to <a href=\"restart\">restart</a> compiler to continue.");
		label.activate_link.connect(() => {
			restart_backend(_project.source_dir(), _level._name);
			return true;
		});

		return label;
	}

	Gtk.Widget compiler_failed_compilation_label()
	{
		Gtk.Label label = new Gtk.Label(null);
		label.set_markup("Data compilation failed.\rFix errors and <a href=\"restart\">restart</a> compiler to continue.");
		label.activate_link.connect(() => {
			restart_backend(_project.source_dir(), _level._name);
			return true;
		});

		return label;
	}

	public void restart_backend(string source_dir, string level_name)
	{
		stop_backend();

		string sd = source_dir;
		string ln = level_name;

		// Reset project state.
		_placeable_type = "";
		_placeable_name = "";

		// Load project and level if any.
		_project.load(sd);
		if (ln != "")
			_level.load(ln);
		else
			_level.load_empty_level();

		_project_slide.show_widget(starting_compiler_label());
		_editor_slide.show_widget(starting_compiler_label());
		_inspector_slide.show_widget(starting_compiler_label());

		// Spawn the data compiler.
		string args[] =
		{
			ENGINE_EXE
			, "--source-dir"
			, _project.source_dir()
			, "--data-dir"
			, _project.data_dir()
			, "--map-source-dir"
			, "core"
			, _project.toolchain_dir()
			, "--server"
			, "--wait-console"
			, null
		};
		GLib.SubprocessLauncher sl = new GLib.SubprocessLauncher(subprocess_flags());
		sl.set_cwd(ENGINE_DIR);
		try
		{
			_compiler_process = sl.spawnv(args);
		}
		catch (Error e)
		{
			loge(e.message);
		}

		// It is an error if the data compiler. disconnects after here.
		_compiler.disconnected.disconnect(on_compiler_disconnected);
		_compiler.disconnected.connect(on_compiler_disconnected_unexpected);

		// Try to connect to data compiler.
		int tries;
		for (tries = 0; tries < DATA_COMPILER_CONNECTION_TRIES; ++tries)
		{
			_compiler.connect("127.0.0.1", DATA_COMPILER_TCP_PORT);

			if (_compiler.is_connected())
				break;

			GLib.Thread.usleep(DATA_COMPILER_CONNECTION_INTERVAL*1000);
		}
		if (tries == DATA_COMPILER_CONNECTION_TRIES)
		{
			loge("Cannot connect to data_compiler");
			return;
		}

		// Compile data.
		_data_compiler.compile.begin(_project.data_dir(), _project.platform(), (obj, res) => {
			if (_data_compiler.compile.end(res))
			{
				// If successful, start the level editor.
				restart_editor();

				_project_slide.show_widget(_project_browser);
				_inspector_slide.show_widget(_inspector_pane);
			}
			else
			{
				_project_slide.show_widget(compiler_failed_compilation_label());
				_editor_slide.show_widget(compiler_failed_compilation_label());
				_inspector_slide.show_widget(compiler_failed_compilation_label());
			}
		});
	}

	private void stop_backend()
	{
		stop_game();
		stop_editor();
		stop_data_compiler();
	}

	private void stop_data_compiler()
	{
		if (_compiler != null && _compiler.is_connected())
		{
			// Explicit call to this function should not produce error messages.
			_compiler.disconnected.disconnect(on_compiler_disconnected_unexpected);
			_compiler.disconnected.connect(on_compiler_disconnected);

			_compiler.send(DataCompilerApi.quit());
			_compiler.close();
		}

		if (_compiler_process != null)
		{
			try
			{
				_compiler_process.wait();
			}
			catch (Error e)
			{
				loge(e.message);
			}
		}
	}

	private void start_editor(uint window_xid)
	{
		if (window_xid == 0)
			return;

		// Spawn the level editor.
		string args[] =
		{
			ENGINE_EXE
			, "--data-dir"
			, _project.data_dir()
			, "--boot-dir"
			, LEVEL_EDITOR_BOOT_DIR
			, "--parent-window"
			, window_xid.to_string()
			, "--wait-console"
			, null
		};
		GLib.SubprocessLauncher sl = new GLib.SubprocessLauncher(subprocess_flags());
		sl.set_cwd(ENGINE_DIR);
		try
		{
			_editor_process = sl.spawnv(args);
		}
		catch (Error e)
		{
			loge(e.message);
		}

		// It is an error if the level editor disconnects after here.
		_editor.disconnected.disconnect(on_editor_disconnected);
		_editor.disconnected.connect(on_editor_disconnected_unexpected);

		// Try to connect to the level editor.
		int tries;
		for (tries = 0; tries < EDITOR_CONNECTION_TRIES; ++tries)
		{
			_editor.connect("127.0.0.1", EDITOR_TCP_PORT);

			if (_editor.is_connected())
				break;

			GLib.Thread.usleep(EDITOR_CONNECTION_INTERVAL*1000);
		}
		if (tries == EDITOR_CONNECTION_TRIES)
		{
			loge("Cannot connect to level_editor");
			return;
		}

		// Update the editor state.
		_level.send_level();
		send_state();
		_preferences_dialog.apply();
	}

	private void stop_editor()
	{
		_resource_chooser.stop_editor();

		if (_editor != null && _editor.is_connected())
		{
			// Explicit call to this function should not produce error messages.
			_editor.disconnected.disconnect(on_editor_disconnected_unexpected);
			_editor.disconnected.connect(on_editor_disconnected);

			_editor.send_script("Device.quit()");
			_editor.close();
		}

		if (_editor_process != null)
		{
			try
			{
				_editor_process.wait();
			}
			catch (Error e)
			{
				loge(e.message);
			}
		}

		_editor_slide.show_widget(new Gtk.Label("Disconnected."));
	}

	private void restart_editor()
	{
		stop_editor();

		if (_editor_view != null)
		{
			_editor_view_overlay.remove(_editor_view);
			_editor_view = null;
		}

		_editor_view = new EditorView(_editor);
		_editor_view.realized.connect(on_editor_view_realized);
		_editor_view.button_press_event.connect(on_button_press);
		_editor_view.button_release_event.connect(on_button_release);

		_editor_view_overlay.add(_editor_view);
		_editor_slide.show_widget(_editor_view_overlay);

		_resource_chooser.restart_editor();
	}

	private void start_game(StartGame sg)
	{
		_project.dump_test_level(_database);

		_data_compiler.compile.begin(_project.data_dir(), _project.platform(), (obj, res) => {
			if (_data_compiler.compile.end(res))
			{
				// Spawn the game.
				string args[] =
				{
					ENGINE_EXE
					, "--data-dir"
					, _project.data_dir()
					, "--console-port"
					, GAME_TCP_PORT.to_string()
					, "--wait-console"
					, "--lua-string"
					, sg == StartGame.TEST ? "TEST=true" : ""
					, null
				};
				GLib.SubprocessLauncher sl = new GLib.SubprocessLauncher(subprocess_flags());
				sl.set_cwd(ENGINE_DIR);
				try
				{
					_game_process = sl.spawnv(args);
				}
				catch (Error e)
				{
					loge(e.message);
				}

				// Try to connect to the game.
				int tries;
				for (tries = 0; tries < GAME_CONNECTION_TRIES; ++tries)
				{
					_game.connect("127.0.0.1", GAME_TCP_PORT);

					if (_game.is_connected())
						break;

					GLib.Thread.usleep(GAME_CONNECTION_INTERVAL*1000);
				}
				if (tries == GAME_CONNECTION_TRIES)
				{
					loge("Cannot connect to game");
					return;
				}
			}
			else
			{
				_toolbar_run.icon_name = "game-run";
			}
		});
	}

	private void stop_game()
	{
		if (_game != null && _game.is_connected())
		{
			_game.send_script("Device.quit()");
			_game.close();
		}

		if (_game_process != null)
		{
			try
			{
				_game_process.wait();
			}
			catch (Error e)
			{
				loge(e.message);
			}
		}
	}

	private void deploy_game()
	{
		Gtk.FileChooserDialog fcd = new Gtk.FileChooserDialog("Select destination directory..."
			, this.active_window
			, FileChooserAction.SELECT_FOLDER
			, "Cancel"
			, ResponseType.CANCEL
			, "Open"
			, ResponseType.ACCEPT
			);

		if (fcd.run() == ResponseType.ACCEPT)
		{
			GLib.File data_dir = File.new_for_path(fcd.get_filename());

			string args[] =
			{
				ENGINE_EXE,
				"--source-dir", _project.source_dir(),
				"--map-source-dir", "core", _project.toolchain_dir(),
				"--data-dir", data_dir.get_path(),
				"--compile",
				null
			};

			GLib.SubprocessLauncher sl = new GLib.SubprocessLauncher(subprocess_flags());
			sl.set_cwd(ENGINE_DIR);
			try
			{
				GLib.Subprocess compiler = sl.spawnv(args);
				compiler.wait();
				if (compiler.get_exit_status() == 0)
				{
					string game_name = DEPLOY_DEFAULT_NAME;
					GLib.File engine_exe_src = File.new_for_path(DEPLOY_EXE);
					GLib.File engine_exe_dst = File.new_for_path(Path.build_filename(data_dir.get_path(), game_name + EXE_SUFFIX));
					engine_exe_src.copy(engine_exe_dst, FileCopyFlags.OVERWRITE);

#if CROWN_PLATFORM_WINDOWS
					string lua51_name = "lua51.dll";
					GLib.File lua51_dll_src = File.new_for_path(lua51_name);
					GLib.File lua51_dll_dst = File.new_for_path(Path.build_filename(data_dir.get_path(), lua51_name));
					lua51_dll_src.copy(lua51_dll_dst, FileCopyFlags.OVERWRITE);

					string openal_name = "openal-release.dll";
					GLib.File openal_dll_src = File.new_for_path(openal_name);
					GLib.File openal_dll_dst = File.new_for_path(Path.build_filename(data_dir.get_path(), openal_name));
					openal_dll_src.copy(openal_dll_dst, FileCopyFlags.OVERWRITE);
#endif // CROWN_PLATFORM_WINDOWS

					logi("Project deployed to `%s`".printf(data_dir.get_path()));
				}
			}
			catch (Error e)
			{
				logi("%s".printf(e.message));
				logi("Failed to deploy project");
			}
		}

		fcd.destroy();
	}

	private void on_editor_view_realized()
	{
		start_editor(_editor_view.window_id);
	}

	private void on_tool_changed(GLib.SimpleAction action, GLib.Variant? param)
	{
		string name = param.get_string();
		if (name == "place")
		{
			// Store previous tool for it to be restored later.
			if (_tool_type != LevelEditorApi.ToolType.PLACE)
				_tool_type_prev = _tool_type;

			_tool_type = LevelEditorApi.ToolType.PLACE;
		}
		else if (name == "move")
			_tool_type = LevelEditorApi.ToolType.MOVE;
		else if (name == "rotate")
			_tool_type = LevelEditorApi.ToolType.ROTATE;
		else if (name == "scale")
			_tool_type = LevelEditorApi.ToolType.SCALE;

		_editor_view.grab_focus();
		send_state();
		action.set_state(param);
	}

	private void on_snap_mode_changed(GLib.SimpleAction action, GLib.Variant? param)
	{
		string name = param.get_string();
		if (name == "relative")
			_snap_mode = LevelEditorApi.SnapMode.RELATIVE;
		else if (name == "absolute")
			_snap_mode = LevelEditorApi.SnapMode.ABSOLUTE;

		send_state();
		action.set_state(param);
	}

	private void on_reference_system_changed(GLib.SimpleAction action, GLib.Variant? param)
	{
		string name = param.get_string();
		if (name == "local")
			_reference_system = LevelEditorApi.ReferenceSystem.LOCAL;
		else if (name == "world")
			_reference_system = LevelEditorApi.ReferenceSystem.WORLD;

		send_state();
		action.set_state(param);
	}

	private void on_grid_changed(GLib.SimpleAction action, GLib.Variant? param)
	{
		_grid_size = float.parse(param.get_string());
		send_state();
		action.set_state(param);
	}

	private void on_rotation_snap_changed(GLib.SimpleAction action, GLib.Variant? param)
	{
		_rotation_snap = float.parse(param.get_string());
		send_state();
		action.set_state(param);
	}

	private void new_level()
	{
		_level.load_empty_level();
		_level.send_level();
	}

	private void load_level(string name)
	{
		if (name == _level._name)
			return;

		_level.load(name);
		_level.send_level();
		send_state();
	}

	private bool save_as(string? filename)
	{
		string path = filename;

		if (path == null)
		{
			Gtk.FileChooserDialog fcd = new Gtk.FileChooserDialog("Save As..."
				, this.active_window
				, FileChooserAction.SAVE
				, "Cancel"
				, ResponseType.CANCEL
				, "Save"
				, ResponseType.ACCEPT
				);
			fcd.add_filter(_file_filter);
			fcd.set_current_folder(_project.source_dir());

			int rt = ResponseType.CANCEL;
			do
			{
				// Select the file
				rt = fcd.run();
				if (rt != ResponseType.ACCEPT)
				{
					fcd.destroy();
					return false;
				}
				path = fcd.get_filename();

				// Append file extension
				if (!path.has_suffix(".level"))
					path += ".level";

				// Check if the file is within the source directory
				if (!_project.path_is_within_dir(path, _project.source_dir()))
				{
					Gtk.MessageDialog md = new Gtk.MessageDialog(fcd
						, DialogFlags.MODAL
						, MessageType.WARNING
						, Gtk.ButtonsType.OK
						, "The file must be within the source directory."
						);
					md.set_default_response(ResponseType.OK);

					md.run();
					md.destroy();
					fcd.set_current_folder(_project.source_dir());
					continue;
				}

				// Check if the file already exists
				rt = ResponseType.YES;
				if (GLib.FileUtils.test(path, FileTest.EXISTS))
				{
					Gtk.MessageDialog md = new Gtk.MessageDialog(fcd
						, DialogFlags.MODAL
						, MessageType.QUESTION
						, Gtk.ButtonsType.YES_NO
						, "A file named `%s` already exists.\nOverwrite?".printf(_project.basename(path))
						);
					md.set_default_response(ResponseType.NO);

					rt = md.run();
					md.destroy();
				}
			}
			while (rt != ResponseType.YES);

			fcd.destroy();
		}

		// Save level
		string resource_filename = _project.absolute_path_to_resource_filename(path);
		string resource_path     = _project.resource_filename_to_resource_path(resource_filename);
		string resource_name     = _project.resource_path_to_resource_name(resource_path);

		_level.save(resource_name);
		_statusbar.set_temporary_message("Saved %s".printf(_level._path));
		return true;
	}

	private bool save()
	{
		return save_as(_level._path);
	}

	private bool save_timeout()
	{
		if (_level._path != null)
			save();

		return true;
	}

	public void close_all()
	{
		// Disable auto-save.
		if (_save_timer_id > 0)
			GLib.Source.remove(_save_timer_id);

		stop_backend();

		// Save editor settings.
		_user.save(_user_file.get_path());
		save_settings();

		// Destroy widgets.
		if (_resource_chooser != null)
			_resource_chooser.destroy();

		if (_preferences_dialog != null)
			_preferences_dialog.destroy();
	}

	protected override void shutdown()
	{
		base.shutdown();
	}

	// Returns true if the level has been saved or the user decided it
	// should be discarded.
	public bool should_quit()
	{
		int rt = ResponseType.YES;

		if (_database.changed())
			rt = run_level_changed_dialog(this.active_window);

		if (!_database.changed() || rt == ResponseType.YES && save() || rt == ResponseType.NO)
			return true;

		return false;
	}

	private void on_new_level(GLib.SimpleAction action, GLib.Variant? param)
	{
		int rt = ResponseType.YES;

		if (_database.changed())
			rt = run_level_changed_dialog(this.active_window);

		if (!_database.changed() || rt == ResponseType.YES && save() || rt == ResponseType.NO)
		{
			new_level();
			send_state();
		}
	}

	private void on_open_level_from_menubar(GLib.SimpleAction action, GLib.Variant? param)
	{
		string path = "";

		Gtk.FileChooserDialog fcd = new Gtk.FileChooserDialog("Open Level..."
			, this.active_window
			, FileChooserAction.OPEN
			, "Cancel"
			, ResponseType.CANCEL
			, "Open"
			, ResponseType.ACCEPT
			);
		fcd.add_filter(_file_filter);
		fcd.set_current_folder(_project.source_dir());

		int err = 1;
		int rt = ResponseType.CANCEL;
		do
		{
			// Select the file
			rt = fcd.run();
			if (rt != ResponseType.ACCEPT)
			{
				fcd.destroy();
				return;
			}
			path = fcd.get_filename();
			err = 0;

			// Append file extension
			if (!path.has_suffix(".level"))
				path += ".level";

			if (!_project.path_is_within_dir(path, _project.source_dir()))
			{
				Gtk.MessageDialog md = new Gtk.MessageDialog(fcd
					, DialogFlags.MODAL
					, MessageType.WARNING
					, Gtk.ButtonsType.OK
					, "The file must be within the source directory."
					);
				md.set_default_response(ResponseType.OK);

				md.run();
				md.destroy();
				fcd.set_current_folder(_project.source_dir());
				err = 1;
				continue;
			}
		}
		while (err != 0);

		fcd.destroy();

		assert(path != "");

		// Load level
		string resource_filename = _project.absolute_path_to_resource_filename(path);
		string resource_path     = _project.resource_filename_to_resource_path(resource_filename);
		string resource_name     = _project.resource_path_to_resource_name(resource_path);

		load_level(resource_name);
	}

	private void on_open_level(GLib.SimpleAction action, GLib.Variant? param)
	{
		int rt = ResponseType.YES;

		string level_name = param.get_string();
		if (level_name != "" && level_name == _level._name)
			return;

		if (_database.changed())
			rt = run_level_changed_dialog(this.active_window);

		if (!_database.changed() || rt == ResponseType.YES && save() || rt == ResponseType.NO)
		{
			if (level_name != "")
				load_level(level_name);
			else // Action invoked from menubar File > Open Level...
				on_open_level_from_menubar(action, param);
		}
	}

	private void on_open_project(GLib.SimpleAction action, GLib.Variant? param)
	{
		int rt = ResponseType.YES;

		if (_database.changed())
			rt = run_level_changed_dialog(this.active_window);

		if (!_database.changed() || rt == ResponseType.YES && save() || rt == ResponseType.NO)
		{
			string source_dir;
			rt = run_open_project_dialog(out source_dir, this.active_window);
			if (rt != ResponseType.ACCEPT)
				return;

			if (_project.source_dir() == source_dir)
				return;

			logi("Loading project: `%s`...".printf(source_dir));
			restart_backend(source_dir, LEVEL_NONE);
		}
	}

	private void on_new_project(GLib.SimpleAction action, GLib.Variant? param)
	{
		int rt = ResponseType.YES;

		if (_database.changed())
			rt = run_level_changed_dialog(this.active_window);

		if (!_database.changed() || rt == ResponseType.YES && save() || rt == ResponseType.NO)
		{
			stop_backend();
			show_panel("panel_new_project");
		}
	}

	private void on_save(GLib.SimpleAction action, GLib.Variant? param)
	{
		save();
	}

	private void on_save_as(GLib.SimpleAction action, GLib.Variant? param)
	{
		save_as(null);
	}

	private void on_import(GLib.SimpleAction action, GLib.Variant? param)
	{
		_project.import(null, this.active_window);
	}

	private void on_preferences(GLib.SimpleAction action, GLib.Variant? param)
	{
		_preferences_dialog.show_all();
	}

	private void on_deploy(GLib.SimpleAction action, GLib.Variant? param)
	{
		deploy_game();
	}

	private int run_level_changed_dialog(Gtk.Window? parent)
	{
		Gtk.MessageDialog md = new Gtk.MessageDialog(parent
			, Gtk.DialogFlags.MODAL
			, Gtk.MessageType.WARNING
			, Gtk.ButtonsType.NONE
			, "Save changes to Level before closing?"
			);
		md.add_button("Close _without Saving", ResponseType.NO);
		md.add_button("_Cancel", ResponseType.CANCEL);
		md.add_button("_Save", ResponseType.YES);
		md.set_default_response(ResponseType.YES);
		int rt = md.run();
		md.destroy();
		return rt;
	}

	public int run_open_project_dialog(out string source_dir, Gtk.Window? parent)
	{
		Gtk.FileChooserDialog fcd = new Gtk.FileChooserDialog("Open Project..."
			, parent
			, FileChooserAction.SELECT_FOLDER
			, "Cancel"
			, ResponseType.CANCEL
			, "Open"
			, ResponseType.ACCEPT
			);
		int rt = fcd.run();
		source_dir = fcd.get_filename();
		fcd.destroy();
		return rt;
	}

	private void on_close(GLib.SimpleAction action, GLib.Variant? param)
	{
		int rt = ResponseType.YES;

		if (_database.changed())
			rt = run_level_changed_dialog(this.active_window);

		if (!_database.changed() || rt == ResponseType.YES && save() || rt == ResponseType.NO)
		{
			stop_backend();
			show_panel("panel_welcome");
		}
	}

	private void on_quit(GLib.SimpleAction action, GLib.Variant? param)
	{
		this.active_window.close();
	}

	private void on_show_grid(GLib.SimpleAction action, GLib.Variant? param)
	{
		_show_grid = !action.get_state().get_boolean();
		send_state();
		action.set_state(new GLib.Variant.boolean(_show_grid));
	}

	private void on_custom_grid()
	{
		Gtk.Dialog dg = new Gtk.Dialog.with_buttons("Grid size"
			, this.active_window
			, DialogFlags.MODAL
			, "Cancel"
			, ResponseType.CANCEL
			, "Ok"
			, ResponseType.OK
			, null
			);

		EntryDouble sb = new EntryDouble(_grid_size, 0.1, 1000);
		sb.activate.connect(() => { dg.response(ResponseType.OK); });
		dg.get_content_area().add(sb);
		dg.skip_taskbar_hint = true;
		dg.show_all();

		if (dg.run() == ResponseType.OK)
		{
			_grid_size = sb.value;
			send_state();
		}

		dg.destroy();
	}

	private void on_rotation_snap(GLib.SimpleAction action, GLib.Variant? param)
	{
		Gtk.Dialog dg = new Gtk.Dialog.with_buttons("Rotation snap"
			, this.active_window
			, DialogFlags.MODAL
			, "Cancel"
			, ResponseType.CANCEL
			, "Ok"
			, ResponseType.OK
			, null
			);

		EntryDouble sb = new EntryDouble(_rotation_snap, 1.0, 180.0);
		sb.activate.connect(() => { dg.response(ResponseType.OK); });
		dg.get_content_area().add(sb);
		dg.skip_taskbar_hint = true;
		dg.show_all();

		if (dg.run() == ResponseType.OK)
		{
			_rotation_snap = sb.value;
			send_state();
		}

		dg.destroy();
	}

	private void on_create_primitive(GLib.SimpleAction action, GLib.Variant? param)
	{
		if (action.name == "primitive-cube")
			set_placeable("unit", "core/units/primitives/cube");
		else if (action.name == "primitive-sphere")
			set_placeable("unit", "core/units/primitives/sphere");
		else if (action.name == "primitive-cone")
			set_placeable("unit", "core/units/primitives/cone");
		else if (action.name == "primitive-cylinder")
			set_placeable("unit", "core/units/primitives/cylinder");
		else if (action.name == "primitive-plane")
			set_placeable("unit", "core/units/primitives/plane");
		else if (action.name == "camera")
			set_placeable("unit", "core/units/camera");
		else if (action.name == "light")
			set_placeable("unit", "core/units/light");
		else if (action.name == "sound-source")
			set_placeable("sound", "");

		activate_action("tool", new GLib.Variant.string("place"));
	}

	private void on_camera_view(GLib.SimpleAction action, GLib.Variant? param)
	{
		string name = param.get_string();

		if (name == "perspective")
			_editor.send_script("LevelEditor:camera_view_perspective()");
		else if (name == "front")
			_editor.send_script("LevelEditor:camera_view_front()");
		else if (name == "back")
			_editor.send_script("LevelEditor:camera_view_back()");
		else if (name == "right")
			_editor.send_script("LevelEditor:camera_view_right()");
		else if (name == "left")
			_editor.send_script("LevelEditor:camera_view_left()");
		else if (name == "top")
			_editor.send_script("LevelEditor:camera_view_top()");
		else if (name == "bottom")
			_editor.send_script("LevelEditor:camera_view_bottom()");

		action.set_state(param);
	}

	private void on_resource_chooser(GLib.SimpleAction action, GLib.Variant? param)
	{
		_resource_popover.show_all();
	}

	private void on_project_browser(GLib.SimpleAction action, GLib.Variant? param)
	{
		if (_project_slide.is_visible())
		{
			_project_slide.hide();
		}
		else
		{
			_project_slide.show_all();
		}
	}

	private void on_console(GLib.SimpleAction action, GLib.Variant? param)
	{
		if (_console_view.is_visible())
		{
			if (_console_view._entry.has_focus)
				_console_view.hide();
			else
				_console_view._entry.grab_focus();
		}
		else
		{
			_console_view.show_all();
		}
	}

	private void on_statusbar(GLib.SimpleAction action, GLib.Variant? param)
	{
		if (_statusbar.is_visible())
		{
			_statusbar.hide();
		}
		else
		{
			_statusbar.show_all();
		}
	}

	private void on_inspector(GLib.SimpleAction action, GLib.Variant? param)
	{
		if (_inspector_slide.is_visible())
		{
			_inspector_slide.hide();
		}
		else
		{
			_inspector_slide.show_all();
		}
	}

	private void on_restart_editor_view(GLib.SimpleAction action, GLib.Variant? param)
	{
		restart_editor();
	}

	private void on_build_data(GLib.SimpleAction action, GLib.Variant? param)
	{
		_data_compiler.compile.begin(_project.data_dir(), _project.platform(), (obj, res) => {
			_data_compiler.compile.end(res);
		});
	}

	private void on_refresh_lua(GLib.SimpleAction action, GLib.Variant? param)
	{
		_data_compiler.compile.begin(_project.data_dir(), _project.platform(), (obj, res) => {
			if (_data_compiler.compile.end(res))
			{
				_editor.send(DeviceApi.refresh());
				_game.send(DeviceApi.refresh());
			}
		});
	}

	private void on_snap_to_grid(GLib.SimpleAction action, GLib.Variant? param)
	{
		_snap_to_grid = !action.get_state().get_boolean();
		send_state();
		action.set_state(new GLib.Variant.boolean(_snap_to_grid));
	}

	private void on_debug_render_world(GLib.SimpleAction action, GLib.Variant? param)
	{
		_debug_render_world = !action.get_state().get_boolean();
		send_state();
		action.set_state(new GLib.Variant.boolean(_debug_render_world));
	}

	private void on_debug_physics_world(GLib.SimpleAction action, GLib.Variant? param)
	{
		_debug_physics_world = !action.get_state().get_boolean();
		send_state();
		action.set_state(new GLib.Variant.boolean(_debug_physics_world));
	}

	private void on_run_game(GLib.SimpleAction action, GLib.Variant? param)
	{
		if (_game.is_connected())
		{
			stop_game();
		}
		else
		{
			// Always change icon state regardless of failures
			_toolbar_run.icon_name = "game-stop";
			start_game(action.name == "test-level" ? StartGame.TEST : StartGame.NORMAL);
		}
	}

	private void on_undo(GLib.SimpleAction action, GLib.Variant? param)
	{
		int id = _database.undo();
		if (id != -1)
			_statusbar.set_temporary_message("Undo: " + ActionNames[id]);
	}

	private void on_redo(GLib.SimpleAction action, GLib.Variant? param)
	{
		int id = _database.redo();
		if (id != -1)
			_statusbar.set_temporary_message("Redo: " + ActionNames[id]);
	}

	private void on_duplicate(GLib.SimpleAction action, GLib.Variant? param)
	{
		_level.duplicate_selected_objects();
	}

	private void on_delete(GLib.SimpleAction action, GLib.Variant? param)
	{
		_level.destroy_selected_objects();
	}

	private void on_manual(GLib.SimpleAction action, GLib.Variant? param)
	{
		try
		{
			AppInfo.launch_default_for_uri("https://dbartolini.github.io/crown/html/v" + CROWN_VERSION, null);
		}
		catch (Error e)
		{
			loge(e.message);
		}
	}

	private void on_report_issue(GLib.SimpleAction action, GLib.Variant? param)
	{
		try
		{
			AppInfo.launch_default_for_uri("https://github.com/dbartolini/crown/issues", null);
		}
		catch (Error e)
		{
			loge(e.message);
		}
	}

	private void on_browse_logs(GLib.SimpleAction action, GLib.Variant? param)
	{
		open_directory(_logs_dir.get_path());
	}

	private void on_changelog(GLib.SimpleAction action, GLib.Variant? param)
	{
		try
		{
			AppInfo.launch_default_for_uri("https://dbartolini.github.io/crown/html/v" + CROWN_VERSION + "/changelog.html", null);
		}
		catch (Error e)
		{
			loge(e.message);
		}
	}

	private void on_about(GLib.SimpleAction action, GLib.Variant? param)
	{
		Gtk.AboutDialog dlg = new Gtk.AboutDialog();
		dlg.set_destroy_with_parent(true);
		dlg.set_transient_for(this.active_window);
		dlg.set_modal(true);
		dlg.set_logo_icon_name("pepper");

		dlg.program_name = "Crown Game Engine";
		dlg.version = CROWN_VERSION;
		dlg.website = "https://github.com/dbartolini/crown";
		dlg.copyright = "Copyright (c) 2012-2020 Daniele Bartolini and individual contributors.";
		dlg.license = "Crown Game Engine.\n"
			+ "Copyright (c) 2012-2020 Daniele Bartolini and individual contributors.\n"
			+ "\n"
			+ "This program is free software; you can redistribute it and/or\n"
			+ "modify it under the terms of the GNU General Public License\n"
			+ "as published by the Free Software Foundation; either version 2\n"
			+ "of the License, or (at your option) any later version.\n"
			+ "\n"
			+ "This program is distributed in the hope that it will be useful,\n"
			+ "but WITHOUT ANY WARRANTY; without even the implied warranty of\n"
			+ "MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the\n"
			+ "GNU General Public License for more details.\n"
			+ "\n"
			+ "You should have received a copy of the GNU General Public License\n"
			+ "along with this program; if not, write to the Free Software\n"
			+ "Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.\n"
			;
		dlg.run();
		dlg.destroy();
	}

	public void set_autosave_timer(uint minutes)
	{
		if (_save_timer_id > 0)
			GLib.Source.remove(_save_timer_id);

		_save_timer_id = GLib.Timeout.add_seconds(minutes*60, save_timeout);
	}

	public void menu_set_enabled(bool enabled, GLib.ActionEntry[] entries, string[]? whitelist = null)
	{
		for (int ii = 0; ii < entries.length; ++ii)
		{
			string action_name = entries[ii].name;
			int jj = 0;
			if (whitelist != null)
			{
				for (; jj < whitelist.length; ++jj)
				{
					if (action_name == whitelist[jj])
						break;
				}
			}
			if (whitelist == null || whitelist != null && jj == whitelist.length)
			{
				GLib.SimpleAction sa = this.lookup_action(action_name) as GLib.SimpleAction;
				if (sa != null)
					sa.set_enabled(enabled);
			}
		}
	}

	private void set_conflicting_accels(bool on)
	{
		if (on)
		{
			this.set_accels_for_action("app.tool::place", _tool_place_accels);
			this.set_accels_for_action("app.tool::move", _tool_move_accels);
			this.set_accels_for_action("app.tool::rotate", _tool_rotate_accels);
			this.set_accels_for_action("app.tool::scale", _tool_scale_accels);
			this.set_accels_for_action("app.camera-view::perspective", _camera_view_perspective_accels);
			this.set_accels_for_action("app.camera-view::front", _camera_view_front_accels);
			this.set_accels_for_action("app.camera-view::back", _camera_view_back_accels);
			this.set_accels_for_action("app.camera-view::right", _camera_view_right_accels);
			this.set_accels_for_action("app.camera-view::left", _camera_view_left_accels);
			this.set_accels_for_action("app.camera-view::top", _camera_view_top_accels);
			this.set_accels_for_action("app.camera-view::bottom", _camera_view_bottom_accels);
		}
		else
		{
			this.set_accels_for_action("app.tool::place", {});
			this.set_accels_for_action("app.tool::move", {});
			this.set_accels_for_action("app.tool::rotate", {});
			this.set_accels_for_action("app.tool::scale", {});
			this.set_accels_for_action("app.camera-view::perspective", {});
			this.set_accels_for_action("app.camera-view::front", {});
			this.set_accels_for_action("app.camera-view::back", {});
			this.set_accels_for_action("app.camera-view::right", {});
			this.set_accels_for_action("app.camera-view::left", {});
			this.set_accels_for_action("app.camera-view::top", {});
			this.set_accels_for_action("app.camera-view::bottom", {});
		}
	}

	public void entry_any_focus_in(Gtk.Widget widget)
	{
		set_conflicting_accels(false);
	}

	public void entry_any_focus_out(Gtk.Widget widget)
	{
		set_conflicting_accels(true);
	}

	public void show_panel(string name, Gtk.StackTransitionType stt = Gtk.StackTransitionType.NONE)
	{
		_main_stack.set_visible_child_full(name, stt);

		if (name == "main_vbox")
		{
			// FIXME: save/restore last known window state
			int win_w;
			int win_h;
			this.active_window.get_size(out win_w, out win_h);
			_editor_pane.set_position(210);
			_content_pane.set_position(win_h - 250);
			_inspector_pane.set_position(win_h - 600);
			_main_pane.set_position(win_w - 375);

			menu_set_enabled(true, action_entries_file);
			menu_set_enabled(true, action_entries_edit);
			menu_set_enabled(true, action_entries_create);
			menu_set_enabled(true, action_entries_camera);
			menu_set_enabled(true, action_entries_view);
			menu_set_enabled(true, action_entries_debug);
			menu_set_enabled(true, action_entries_help);
		}
		else if (name == "panel_welcome"
			|| name == "panel_new_project"
			|| name == "panel_projects_list"
			)
		{
			menu_set_enabled(false, action_entries_file, {"new-project", "open-project", "quit"});
			menu_set_enabled(false, action_entries_edit);
			menu_set_enabled(false, action_entries_create);
			menu_set_enabled(false, action_entries_camera);
			menu_set_enabled(false, action_entries_view);
			menu_set_enabled(false, action_entries_debug);
			menu_set_enabled( true, action_entries_help);
		}
	}

	public void set_placeable(string type, string name)
	{
		_placeable_type = type;
		_placeable_name = name;
		_editor.send_script(LevelEditorApi.set_placeable(type, name));
	}

	public void activate_last_tool_before_place()
	{
		const string type_to_name[] =
		{
			"place",
			"move",
			"rotate",
			"scale"
		};
		GLib.static_assert(type_to_name.length == LevelEditorApi.ToolType.COUNT);

		if (_tool_type != LevelEditorApi.ToolType.PLACE)
			return;

		activate_action("tool", new GLib.Variant.string(type_to_name[_tool_type_prev]));
	}
}

// Global paths
public static GLib.File _toolchain_dir;
public static GLib.File _templates_dir;
public static GLib.File _config_dir;
public static GLib.File _logs_dir;
public static GLib.File _documents_dir;
public static GLib.File _log_file;
public static GLib.File _settings_file;
public static GLib.File _user_file;

public static GLib.FileStream _log_stream;
public static ConsoleView _console_view;

public static void log(string system, string severity, string message)
{
	GLib.DateTime now = new GLib.DateTime.now_utc();
	string line = "%s.%06d  %.4s %s: %s\n".printf(now.format("%H:%M:%S")
		, now.get_microsecond()
		, severity.ascii_up()
		, system
		, message
		);

	if (_log_stream != null)
	{
		_log_stream.puts(line);
		_log_stream.flush();
	}

	if (_console_view != null)
		_console_view.log(severity, line);
}

public static void logi(string message)
{
	log("editor", "info", message);
}

public static void logw(string message)
{
	log("editor", "warning", message);
}

public static void loge(string message)
{
	log("editor", "error", message);
}

public void open_directory(string directory)
{
#if CROWN_PLATFORM_LINUX
	try
	{
		GLib.AppInfo.launch_default_for_uri("file://" + directory, null);
	}
	catch (Error e)
	{
		loge(e.message);
	}
#else
	GLib.SubprocessLauncher sl = new GLib.SubprocessLauncher(subprocess_flags());
	try
	{
		sl.spawnv({ "explorer.exe", directory, null });
	}
	catch (Error e)
	{
		loge(e.message);
	}
#endif
}

public static GLib.SubprocessFlags subprocess_flags()
{
	GLib.SubprocessFlags flags = SubprocessFlags.NONE;
#if !CROWN_DEBUG
	flags |= SubprocessFlags.STDOUT_SILENCE | SubprocessFlags.STDERR_SILENCE;
#endif
	return flags;
}

public static bool is_directory_empty(string path)
{
	GLib.File file = GLib.File.new_for_path(path);
	try
	{
		FileEnumerator enumerator = file.enumerate_children("standard::*"
			, FileQueryInfoFlags.NOFOLLOW_SYMLINKS
			);
		return enumerator.next_file() == null;
	}
	catch (GLib.Error e)
	{
		loge(e.message);
	}

	return false;
}

public static int main(string[] args)
{
	// Global paths
	_config_dir = GLib.File.new_for_path(GLib.Path.build_filename(GLib.Environment.get_user_config_dir(), "crown"));
	try { _config_dir.make_directory(); } catch (Error e) { /* Nobody cares */ }
	_logs_dir = GLib.File.new_for_path(GLib.Path.build_filename(_config_dir.get_path(), "logs"));
	try { _logs_dir.make_directory(); } catch (Error e) { /* Nobody cares */ }
	_documents_dir = GLib.File.new_for_path(GLib.Environment.get_user_special_dir(GLib.UserDirectory.DOCUMENTS));

	_log_file = GLib.File.new_for_path(GLib.Path.build_filename(_logs_dir.get_path(), new GLib.DateTime.now_utc().format("%Y-%m-%d") + ".log"));
	_settings_file = GLib.File.new_for_path(GLib.Path.build_filename(_config_dir.get_path(), "settings.sjson"));
	_user_file = GLib.File.new_for_path(GLib.Path.build_filename(_config_dir.get_path(), "user.sjson"));

	_log_stream = GLib.FileStream.open(_log_file.get_path(), "a");

	// Find toolchain path, more desirable paths come first.
	int ii = 0;
	string toolchain_paths[] =
	{
		".",
		"../..",
		"../../../samples"
	};
	for (ii = 0; ii < toolchain_paths.length; ++ii)
	{
		string path = Path.build_filename(toolchain_paths[ii], "core");
		if (GLib.FileUtils.test(path, FileTest.EXISTS) && GLib.FileUtils.test(path, FileTest.IS_DIR))
		{
			_toolchain_dir = File.new_for_path(path).get_parent();
			break;
		}
	}
	if (ii == toolchain_paths.length)
	{
		loge("Unable to find the toolchain directory");
		return 1;
	}

	// Find templates path, more desirable paths come first.
	string templates_path[] =
	{
		".",
		"../..",
		"../../.."
	};
	for (ii = 0; ii < templates_path.length; ++ii)
	{
		string path = Path.build_filename(templates_path[ii], "samples");
		if (GLib.FileUtils.test(path, FileTest.EXISTS) && GLib.FileUtils.test(path, FileTest.IS_DIR))
		{
			_templates_dir = File.new_for_path(path);
			break;
		}
	}
	if (ii == templates_path.length)
	{
		loge("Unable to find the templates directory");
		return 1;
	}

	LevelEditorApplication app = new LevelEditorApplication();
	return app.run(args);
}

}
