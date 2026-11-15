# Catálogo vivo del MCP de Unreal 5.8.4

Volcado el 14 de noviembre de 2026 del servidor MCP del editor (plugins ModelContextProtocol y AllToolsets) abierto sin ventana sobre la plantilla TP_BlankBP. El servidor anuncia tres herramientas (`list_toolsets`, `describe_toolset`, `call_tool`); lo demás se llama a través de `call_tool`. Los esquemas completos están en `mcp_catalogo_vivo.json`.

52 toolsets, 830 herramientas.

## ToolsetRegistry.AgentSkillToolset (4)
Provides tools for listing, reading, and creating/updating skills.

- `UpdateSkill`: Updates an existing AgentSkill.
- `ListSkills`: Gets a summary of all AgentSkills in the project.
- `GetSkills`: Returns detailed information about a specific set of AgentSkills.
- `CreateSkill`: Creates a new AgentSkill.

## AutomationTestToolset.AutomationTestToolset (7)
Automation test discovery and execution toolset.

- `StopTests`: Stop all currently running tests. Requires DiscoverTests() to have completed.
- `RunTestsByFilter`: Run automation tests selected by a filter expression. Requires DiscoverTests()
- `RunTests`: Run a set of automation tests by name. Requires DiscoverTests() to have completed.
- `ListTests`: List available automation tests. Requires DiscoverTests() to have completed.
- `GetTestStatus`: Get a lightweight status snapshot of the automation controller.
- `GetTestResults`: Get detailed results for the current or most recent test run.
- `DiscoverTests`: Initialize automation worker discovery and load the test list.

## ConfigSettingsToolset.ConfigSettingsToolset (8)
Tools for listing, inspecting, and editing Config Settings sections

- `SetSectionProperties`: Sets one or more properties on a settings section from a JSON object and saves.
- `SaveSection`: Saves the settings in a section.
- `ResetSectionToDefaults`: Resets the settings in a section to their default values.
- `ListSections`: Lists the names of all sections within a settings category, sorted alphabetically.
- `ListContainers`: Lists the names of all known settings containers, sorted alphabetically.
- `ListCategories`: Lists the names of all categories within a settings container, sorted alphabetically.
- `GetSectionSchema`: Returns a JSON Schema describing the user-visible properties of a settings section.
- `GetSectionPropertyValues`: Returns the current values of the specified properties as a JSON object.

## DataRegistryToolset.DataRegistryTools (7)
Provides tools for querying and inspecting Data Registries.

- `ListRuntimeSources`: Returns the runtime sources for a Data Registry.
- `ListRegistries`: Returns the names of all registered Data Registries.
- `ListItems`: Returns all item names in a Data Registry.
- `ListDataSources`: Returns the editor-defined sources configured on a Data Registry.
- `GetSchema`: Returns the item struct schema as JSON.
- `GetRegistryInfo`: Returns detailed information about a specific registry.
- `GetItems`: Returns cached item data.

## DataflowAgent.DataflowAgentToolset (22)
Dataflow Agent Toolset - exposes Dataflow graph editing operations as AI agent tools.

- `UpdateNode`: Updates an existing node's editable properties via JSON.
- `SetVariable`: Sets the value of an existing variable using its serialized string representation.
- `RepositionNode`: Moves a node to a new position in the graph editor.
- `RemoveVariable`: Removes a variable from the Dataflow graph.
- `RemoveNode`: Removes a node and all its connections from the Dataflow graph.
- `RemoveCommentBox`: Removes a comment box node from the graph.
- `ListVariables`: Returns all variables defined on the Dataflow graph as a JSON array.
- `ListNodeTypes`: Returns a JSON list of all registered Dataflow node types.
- `ListDataflowTemplatesForAssetClass`: Returns a JSON list of Dataflow templates registered for the given asset class.
- `ListDataflowCompatibleAssetTypes`: Returns a JSON list of every UClass that can host an embedded Dataflow graph
- `GetNodeTypeSchema`: Returns the schema for a Dataflow node type including its input/output pins
- `GetNodeInfo`: Returns information about a node as a JSON object (name, type, position, pins).
- `GetGraphStructure`: Returns the complete structure of a Dataflow graph including all nodes and connections.
- `DisconnectNodePins`: Removes the connection between two node pins.
- `CreateGraph`: Creates a new saved Dataflow graph asset.
- `CreateDataflowCompatibleAssetFromTemplate`: Creates a new Dataflow-compatible asset and initialises its embedded Dataflow graph
- `CreateDataflowCompatibleAsset`: Creates a new Dataflow-compatible asset (e.g. ChaosClothAsset, GeometryCollection,
- `ConnectNodePins`: Connects an output pin of one node to an input pin of another.
- `AssignDataflowTemplate`: Assigns a Dataflow template to an existing Dataflow-compatible asset by duplicating
- `AddVariable`: Adds a new variable to the Dataflow graph.
- `AddNode`: Adds a node of the given type to the Dataflow graph.
- `AddCommentBox`: Adds a comment box around the given nodes.

## GameplayTagsToolset.GameplayTagsToolset (6)
Provides tools for reading and managing gameplay tags in the project's GameplayTagsManager.

- `RenameTag`: Renames a gameplay tag, updating all references in the project.
- `RemoveTag`: Removes a gameplay tag from the project.
- `ListTags`: Returns gameplay tags registered in the project.
- `GetTagInfo`: Returns detailed information about a specific gameplay tag.
- `FindReferencersByTag`: Returns assets that reference a gameplay tag.
- `AddTag`: Adds a new gameplay tag to the project.

## GameFeaturesToolset.GameFeaturesToolset (7)
Provides tools for listing, activating, and deactivating Game Feature Plugins.

- `RequestDeactivateGameFeature`: Requests deactivation of a Game Feature Plugin.
- `RequestActivateGameFeature`: Requests activation of a Game Feature Plugin.
- `ListEnabledGameFeaturePlugins`: Lists all enabled Game Feature Plugins  sorted by name. Enabled plugins are the only plugins
- `ListDiscoveredGameFeaturePlugins`: Lists all discovered Game Feature Plugins sorted by name. This includes enabled and disabled
- `IsGameFeaturePlugin`: Return whether or not a plugin is a Game Feature Plugin. Will error if no plugin of this
- `IsGameFeatureActive`: Checks whether a Game Feature Plugin is active. Raises an error if the subsystem is unavailable
- `GetGameFeatureState`: Gets the current state of a Game Feature Plugin.

## EditorToolset.EditorAppToolset (21)
Tools for querying and modifying Unreal Editor state: console variables, asset imaging,

- `WorldPosToScreenCoords`: Converts a world-space position into normalized screen space based on the editor viewport camera.
- `StopPIE`: Stops the currently running play session (PIE or Simulate).
- `StartPIE`: Starts a Play-In-Editor or Simulate-In-Editor session using the current level.
- `SetContentBrowserPath`: Navigates the active content browser to the specified folder path.
- `SetCameraTransform`: Sets the position and rotation of the level viewport camera.
- `SelectAssets`: Selects the specified assets in the content browser.
- `SelectActors`: Selects the specified actors in the current scene.
- `SearchCVars`: Finds all console variables that contain a given name.
- `ScreenCoordsToWorld`: Finds the world position of the nearest solid object at a given set of normalized view space coords.
- `OpenEditorForAsset`: Opens an asset editor for the specified asset.
- `IsPIERunning`: Returns whether a Play In Editor session is currently running.
- `GetVisibleActors`: Returns all actors in the current level whose bounds intersect the viewport frustum.
- `GetSelectedAssets`: Gets the list of assets selected in the content browser.
- `GetSelectedActors`: Gets the currently selected actors in the level editor.
- `GetOpenAssets`: Gets the list of assets currently open in asset editors.
- `GetContentBrowserPath`: Gets the current path of the active content browser.
- `GetCameraTransform`: Returns the position and rotation of the level viewport camera.
- `FocusOnActors`: Repositions the level editor camera to focus on the specified actors.
- `CaptureViewport`: Captures the level viewport with optional annotations.
- `CaptureEditorImage`: Captures an image of the entire editor application as the user sees it.
- `CaptureAssetImage`: Renders a thumbnail for the specified asset (e.g. static meshes, skeletal meshes,

## EditorToolset.LogsToolset (4)
Provides tools for reading the Unreal Engine output log and controlling

- `SetVerbosity`: Sets the verbosity level for a log category.
- `GetVerbosity`: Returns the current verbosity level for a log category.
- `GetLogEntries`: Returns log entries from the current session's log file.
- `GetLogCategories`: Returns a sorted list of registered log categories.

## GASToolsets.GameplayCueToolset (8)
Provides tools for inspecting, executing, and managing gameplay cues and their notify assets.

- `RemoveCueTag`: Removes a gameplay cue tag from the project.
- `ListCues`: Returns gameplay cue tags registered in the project.
- `GetCueInfo`: Returns information about a specific gameplay cue, including its notify asset.
- `FindCueTagsWithoutNotifies`: Returns gameplay cue tags that have no corresponding GameplayCueNotify asset in the project.
- `FindCueNotifyAssets`: Returns all GameplayCueNotify assets found in the project via the asset registry.
- `ExecuteCueOnSelectedActor`: Executes a gameplay cue non-replicated on the currently selected actor in the editor.
- `CreateCueNotifyAsset`: Creates a new GameplayCueNotify Blueprint asset at the specified content browser location.
- `AddCueTag`: Adds a new gameplay cue tag to the project.

## GASToolsets.AttributeSetToolset (2)
Provides tools for discovering AttributeSet classes and their gameplay attributes.

- `ListAttributes`: Returns the gameplay attributes defined on a specific AttributeSet class.
- `FindAttributeSetClasses`: Returns all AttributeSet subclasses found in the project, including their attributes.

## GASToolsets.AbilitySystemInspectorToolset (4)
Provides tools for inspecting the runtime state of an AbilitySystemComponent.

- `GetGrantedAbilities`: Returns all abilities granted to the actor's AbilitySystemComponent.
- `GetAttributeValues`: Returns the current base and modified values of all gameplay attributes
- `GetActiveTags`: Returns the gameplay tags currently owned by the actor's
- `GetActiveEffects`: Returns all gameplay effects currently active on the actor's

## NiagaraToolsets.NiagaraToolset_Info (1)
Niagara Toolset for general Niagara information and guidance.

- `UEnum_Info`: Returns information about a UEnum and all its values.

## NiagaraToolsets.NiagaraToolset_Component (4)
Niagara Toolset for Niagara Component operations.

- `SetVariable`: Sets the value of a user variable on the component.
- `SetSystem`: Sets the Niagara System for a component.
- `GetVariable`: Gets the current value of a specific user variable on the component.
- `GetUserVariables`: Returns all user variable values currently set on the component.

## NiagaraToolsets.NiagaraToolset_Blueprint (2)
Niagara Toolset for Niagara and Blueprint integration.

- `ConstructNiagaraBPWrapperFromSystem`: Creates a Blueprint actor wrapper around a Niagara System.
- `ConstructNiagaraBPWrapperFromComponent`: Creates a Blueprint actor wrapper from a Niagara Component.

## NiagaraToolsets.NiagaraToolset_System (46)
Niagara Toolset for Niagara System operations.

- `SetSystemData`: Sets property values on a Niagara System.
- `SetStackInputData`: Sets the value of a stack module input and returns the resulting stored value.
- `SetRendererData`: Sets property values on a Niagara Renderer.
- `SetModuleEnabled`: Sets whether a module is enabled.
- `SetEmitterData`: Sets property values on a Niagara Emitter.
- `RemoveUserVariables`: Removes user variables from a system.
- `RemoveSetParameterEntry`: Removes a parameter from an existing SetParameters module by name.
- `RemoveRenderer`: Removes a renderer from an emitter.
- `RemoveModule`: Removes a module from a script stack.
- `RemoveEmitter`: Removes an emitter from a system.
- `GetUserVariables`: Returns all user variables defined on the system.
- `GetSystemSummary`: Returns lightweight system metadata: name, user variables, and one summary entry per emitter.
- `GetSystemSchema`: Returns property schema for Niagara System.
- `GetSystemDependencies`: Returns the four Used* sets (renderers, data interfaces, modules, dynamic inputs)
- `GetSystemData`: Returns system property values.
- `GetSystemCompileState`: Returns the current compile state of a Niagara System: aggregate status, per-script compile
- `GetStackIssues`: Returns all stack issues (errors, warnings, info) from the Niagara module stack, including
- `GetStackInputTopology`: Returns stack input topology: name, type, visibility, editability. No value payload.
- `GetStackInputSchema`: Returns schema for a single module input in the stack.
- `GetStackInputData`: Returns the value of a stack module input.
- `GetScriptStackTopology`: Returns script stack topology: all modules and their inputs in execution order.
- `GetScriptStackInputValues`: Returns all resolved input values for every module in the given script stack.
- `GetRendererSchema`: Returns property schema for a specific Renderer class.
- `GetRendererData`: Returns renderer property values.
- `GetModuleTopology`: Returns module topology: metadata and all inputs (name/type/visibility only, no values).
- `GetModuleSchemaFromAsset`: Returns schema for a module asset.
- `GetModuleSchema`: Returns schema for a module and all its inputs.
- `GetModuleInputValues`: Returns resolved input values for a single module.
- `GetEmitterTopology`: Returns full emitter topology: four script stacks with all modules and inputs, renderer references.
- `GetEmitterSummary`: Returns lightweight emitter metadata: name, enabled state, sim target, renderer classes.
- `GetEmitterSchema`: Returns property schema for Niagara Emitter.
- `GetEmitterInputValues`: Returns all resolved input values for every module across all four emitter script stacks.
- `GetEmitterData`: Returns emitter property values as a single JSON-string blob in PropertyValues.
- `GetDynamicInputSchemaFromAsset`: Returns schema for a dynamic input asset.
- `GetDynamicInputSchema`: Returns schema for a dynamic input module in the stack.
- `GetDynamicInputChain`: Returns the full recursive chain for a dynamic input: topology metadata and resolved values at every level.
- `GetDataInterfaceSchema`: Returns property schema for a specific Data Interface class.
- `GetAvailableDynamicInputs`: Returns all available Dynamic Input Module assets compatible with the given type.
- `CreateNiagaraSystem`: Creates a new Niagara System asset.
- `ApplyStackIssueFix`: Applies a Fix-style stack issue fix identified by IssueId and FixId. Link-style fixes are
- `AddUserVariables`: Adds or updates user variables on a system.
- `AddSetParametersModule`: Adds a SetParameters module to a script stack.
- `AddSetParameterEntry`: Adds a single parameter to an existing SetParameters module.
- `AddRenderer`: Adds a renderer to an emitter.
- `AddModule`: Adds a module to a script stack.
- `AddEmitter`: Adds an emitter to a Niagara System.

## NiagaraToolsets.NiagaraToolset_Assets (3)
Niagara Toolset for discovery of Niagara script assets.

- `GetNiagaraScriptDigest`: Returns the decoded asset-registry tag metadata for a Niagara script asset.
- `GetAssetDiscoveryInfo`: Returns the project's configured asset discovery groups.
- `FindNiagaraScripts`: Searches for UNiagaraScript assets matching the given filters.

## PhysicsToolsets.PhysicsAssetToolset (17)
Provides tools for creating and managing Physics Assets.

- `SetSphere`: Adds or replaces a sphere collision primitive on a body.
- `SetConstraintLimits`: Updates the angular limits for an existing constraint.
- `SetCapsule`: Adds or replaces a capsule collision primitive on a body.
- `SetBox`: Adds or replaces a box collision primitive on a body.
- `SetBodyPhysicsMode`: Sets the physics simulation mode for the given body.
- `SetBodyMassScale`: Sets the mass-scale multiplier for the given body.
- `RemoveShape`: Removes a collision primitive from a body by name.
- `RemoveConstraint`: Removes the constraint between two bodies.
- `RemoveBody`: Removes the body for the given bone along with any constraints that reference it.
- `GetConstraints`: Returns all constraints in the physics asset with their current angular limits.
- `GetBodyShapes`: Returns all collision shapes assigned to a body.
- `GetBodyPhysicsMode`: Returns the physics simulation mode for the given body.
- `GetBodyNames`: Returns the bone name for each rigid body in a physics asset.
- `GetBodyMassScale`: Returns the mass-scale multiplier for the given body.
- `CreateFromMesh`: Creates a physics asset from a skeletal mesh, auto-generating collision bodies for
- `AddConstraint`: Adds a new constraint between two bodies. Both bodies must already exist.
- `AddBody`: Adds a new empty body for the given bone.

## PluginToolset.PluginToolset (17)
Tools for creating, editing, enabling, and querying Unreal plugins

- `ValidateNewPluginNameAndLocation`: Validates that PluginName and RelativePluginLocation are acceptable for a new plugin.
- `UpdatePluginDescriptor`: Updates a plugin's descriptor fields and writes them to its .uplugin file.
- `SetPluginEnabled`: Enables or disables a plugin in the project config. The change takes effect on the next editor restart.
- `RemovePluginDependency`: Removes a dependency entry from a plugin's Plugins array in its .uplugin file.
- `ListEnabledPlugins`: Lists the names of all enabled plugins, sorted alphabetically.
- `ListDiscoveredPlugins`: Lists the names of all discovered plugins (enabled and disabled), sorted alphabetically.
- `IsPluginModificationAllowed`: Checks whether the editor settings permit modifying plugins from the plugin browser.
- `IsPluginCreationAllowed`: Checks whether the editor settings permit plugin creation from the plugin browser.
- `IsEnabled`: Checks whether a discovered plugin is currently enabled.
- `GetPluginTemplateDescriptions`: Returns the list of available plugin templates. Pass one of the results to CreatePlugin
- `GetPluginInfo`: Gets metadata for a discovered plugin, including description, version, base directory,
- `GetPluginForAsset`: Returns the name of the enabled plugin whose content mount point contains the given asset path.
- `GetPluginDescriptor`: Gets the editable descriptor fields for a discovered plugin.
- `GetPluginDependents`: Returns the names of all discovered plugins that declare a dependency on the given plugin.
- `GetPluginDependencies`: Returns the dependency entries from a plugin's Plugins array in its .uplugin file.
- `CreatePlugin`: Creates a new plugin from a template and loads it into the editor.
- `AddPluginDependency`: Adds a dependency entry to a plugin's Plugins array in its .uplugin file.

## PCGToolset.PCGToolset (30)
Toolset for building and modifying PCG graphs

- `UpdateNode`: Updates a node by changing its params and/or title.
- `UpdateCommentBox`: Updates an existing comment box with new nodes and value.
- `SpawnGraphInstance`: Spawns a PCG Volume with associated Graph Instance into the scene, optionally with Graph Param overrides.
- `SetNodeComment`: Change the comment on the specified node.
- `SetGraphParams`: Adds one or more graph user parameters to a specific PCG graph, such that they will be overridable in per graph instance.
- `SetGraphInstanceParams`: Sets the graph instance params of a specific actor, actor MUST have a graph instance
- `SetGraphDescription`: Set the description of a PCGGraph
- `ResetGraphInstanceParams`: Resets the given graph instance params back to the graph's default values. Actor MUST have a graph instance.
- `RepositionNode`: Change the position of node.
- `RemoveNode`: Removes the node from the graph, will also remove edges connected to the node.
- `RemoveGraphParams`: Removes graph parameters to a specific PCG graph, such that they are not overridable anymore.
- `RemoveCommentBox`: Removes a comment box from the graph. Does not affect the nodes it contains.
- `ListNativeNodes`: Returns a list of available native PCG node type names.
- `ListGraphInstances`: Gets all actors with a PCG graph instance in the scene.
- `ListAvailableSubgraphs`: Lists the PCG graphs that can be used with the Subgraph native node. Only these graphs should be used with
- `GetNodeInfo`: Returns node details including name, position, and all parameter values.
- `GetNodeDataView`: Returns a JSON Data View of a specific node's output data from the last graph execution.
- `GetNativeNodeSchema`: Returns the schema for a PCG node type including input/output pins,
- `GetGraphStructure`: Returns the complete structure of a PCG graph including all nodes,
- `GetGraphSchema`: Returns the schema for a PCG Graph's graph parameters
- `GetGraphInstanceParams`: Gets the graph instance params of a specific actor, actor MUST have a graph instance
- `GetGraphDescription`: Returns the description of a PCG graph.
- `ExecuteGraphInstance`: Executes the graph instance and returns any issues encountered during execution.
- `DrawSpline`: Triggers the user to draw a spline in the viewport to be used later in the world building. Waits for the user to be done.
- `DisconnectNodePins`: Removes the edge between two nodes connected to the specified pins.
- `CreateGraph`: Creates a new saved PCG graph asset.
- `ConnectNodePins`: Add an edge between two nodes connected to the specified pins.
- `AddSubgraphNode`: Adds a subgraph node to the graph.
- `AddNode`: Adds a native node to the graph.
- `AddCommentBox`: Adds a comment box around the given nodes.

## PCGToolset.PCGSpatialToolset (1)
PCGSpatial Toolset

- `RunPCGInstantGraph`: Runs an instant PCG graph with the specified parameters in fire-and-forget mode

## SemanticSearchToolset.SemanticSearchToolset (2)
Toolset exposing the SemanticSearch plugin's hybrid vector + BM25 asset search

- `Search`: Run a semantic search over the Content Browser assets indexed by the SemanticSearch plugin.
- `FindSimilar`: Find assets whose embeddings are semantically similar to the given asset's embedding.

## SlateInspectorToolset.SlateInspectorToolset (14)
Playwright-style Slate UI automation toolset.

- `Windows`: List, select, or close top-level Slate editor windows.
- `WaitFor`: Check if text is present or absent in the Slate widget tree.
- `Unobserve`: Remove an observer by its identifier.
- `Type`: Type text into a Slate text input widget. Focuses the widget first,
- `Snapshot`: Capture a Slate UI accessibility snapshot.  Use this to read the current
- `SelectOption`: Select an option in a Slate combobox by its text label.
- `Screenshot`: Screenshot a Slate widget or the active editor window. Prefer this over
- `PressKey`: Press and release a keyboard key on the currently focused Slate widget.
- `Observe`: Register an observer on a widget subtree so its refs are continuously
- `ListObservers`: List all active observers as a JSON array for debugging.
- `Hover`: Hover over a Slate widget, triggering any hover state or tooltip.
- `FillForm`: Fill multiple Slate form fields at once.
- `Drag`: Drag from one Slate widget to another (mouse down, move, release).
- `Click`: Click a Slate widget identified by its ref.

## WorldConditionsToolset.WorldConditionTools (2)
Inspect WorldCondition (FWorldConditionQueryDefinition, FWorldConditionBase) structs.

- `GetQueryDescription`: Returns a human-readable description of a world condition query.
- `GetConditionDescription`: Returns a human-readable description of a single world condition.

## UMGToolSet.UMGToolSet (23)
UMG widget toolset for AI-driven widget creation and tree manipulation.

- `WrapWidgets`: Wraps one or more widgets in a new panel widget of the specified class.
- `ToggleWidgetAsVariable`: Sets the bIsVariable flag.
- `SetNamedSlotContent`: Sets content for a named slot. Returns full widget info including Slot pointer.
- `ReplaceWidgetWithTemplate`: Replaces a widget instance in the blueprint's widget tree with a new instance created from a
- `ReplaceWidgetWithNamedSlot`: Replaces a host widget with the content of one of its named slots. The host must implement
- `ReplaceWidgetWithChild`: Replaces a panel widget with its first child, removing the panel from the tree.
- `RenameWidget`: Renames a widget. Returns updated widget info or empty on failure.
- `RemoveWidget`: Removes a widget and its children from the tree.
- `RemoveUIComponent`: Removes a UI component of the given class from the named widget.
- `MoveWidget`: Moves a widget to a new parent panel at the specified position. Returns updated widget info with new Slot.
- `MoveUIComponent`: Moves a UI component before or after another component on the same widget.
- `ListWidgetClasses`: Lists available widget classes, optionally filtered by name substring.
- `ListWidgetBlueprints`: Lists widget blueprints in a content folder.
- `GetWidgetTreeDepth`: Returns the maximum depth of the widget tree. Depth: root with no children = 0; root + children = 1; etc.
- `GetWidgets`: Returns blueprint info and all widgets in depth-first order.
- `GetWidgetDescription`: Full property dump of every widget in the tree.
- `GetWidgetClassInfo`: Returns the Category, Description and if it's a Panel for a single widget class.
- `GetNamedSlots`: Returns named slot bindings (separate from tree hierarchy).
- `CreateWidgetBlueprint`: Creates a new Widget Blueprint asset. Returns the blueprint or nullptr on failure.
- `CompileWidgetBlueprint`: Compiles a widget blueprint. Returns false with error details if compilation fails.
- `BindToEventProperty`: Adds a Blueprint event handler graph node bound to a widget's multicast delegate event,
- `AddWidget`: Adds a widget to the tree at the specified position. Returns full widget info including Slot pointer.
- `AddUIComponent`: Adds a UI component of the given class to the named widget.

## conversation_toolset.toolsets.conversation.ConversationTools (7)
Inspect Conversation Graph (UConversationDatabase) dialogue assets.

- `get_sub_nodes`: Returns sub-nodes (requirements, choices) attached to a task node.
- `get_node_connections`: Returns output connection GUIDs for a conversation node.
- `get_node_by_guid`: Returns a conversation node by its GUID.
- `get_node_guids`: Returns GUIDs of all reachable nodes, in map iteration order.
- `get_all_nodes`: Returns all reachable nodes in the conversation.
- `list_speakers`: Returns speaker/participant information.
- `list_entry_points`: Returns entry points (FConversationEntryList structs).

## state_tree_toolset.toolsets.state_tree.StateTreeTools (9)
Inspect StateTree (ST) assets.

- `get_node_description`: Returns a human-readable description for a node.
- `get_evaluators`: Returns global evaluators.
- `get_global_tasks`: Returns global tasks that run across all states.
- `get_transitions`: Returns transitions on a state.
- `get_enter_conditions`: Returns enter conditions on a state.
- `get_tasks`: Returns tasks on a state.
- `get_children`: Returns child states of a state.
- `get_root_states`: Returns top-level states of a StateTree.
- `get_editor_data`: Returns the editor data for a StateTree asset.

## editor_toolset.toolsets.actor.ActorTools (17)
Provides tools for inspecting and modifying actors, including

- `remove_component`: Removes a component from an actor instance or blueprint.
- `add_component`: Adds a component to an actor instance or blueprint.
- `get_components`: Returns the components that an actor contains.
- `get_actor_bounds`: Returns the bounding box of an actor.
- `set_parent_component`: Sets the parent for the specified scene component.
- `get_parent_component`: Returns the parent component that this component is attached to, if any.
- `get_component_actor`: Returns the actor that owns the specified component.
- `get_root_component`: Returns the root component of an actor, if any.
- `look_at`: Rotates an actor so its forward vector points at a world-space position.
- `set_actor_transform`: Updates the position, rotation, and/or scale of an actor.
- `get_actor_transform`: Returns the position, rotation, and scale of an actor.
- `remove_tag`: Removes a tag from an actor.
- `add_tag`: Adds a tag to an actor.
- `has_tag`: Returns whether an actor has a specific tag.
- `get_tags`: Returns the list of tags on an actor.
- `set_label`: Sets the human-friendly name of the actor.
- `get_label`: Returns the actor's human friendly name as it appears in the editor.

## editor_toolset.toolsets.asset.AssetTools (21)
Provides tools for interacting with assets in the Unreal project and files on disk.

- `write_file`: Writes text content to a file on disk.
- `read_file`: Reads a text file from disk and returns its contents.
- `get_plugin_content_paths`: Returns the root content paths for plugins that have content.
- `get_dependencies`: Lists assets that the specified asset depends on.
- `get_referencers`: Lists assets that reference the specified asset.
- `is_checked_out`: Checks whether an asset is checked out by the current user.
- `can_edit_asset`: Checks whether an asset can be edited.
- `is_dirty`: Checks whether an asset has unsaved changes.
- `save_assets`: Saves assets to disk.
- `load_asset`: Loads an asset from the project.
- `update_metadata_tags`: Sets or removes metadata tags on an asset.
- `get_metadata_tags`: Gets the metadata tags for an asset.
- `get_asset_class`: Gets the class of an asset.
- `get_asset_tags`: Gets the asset registry tags for an asset.
- `find_assets`: Searches the project for assets that match specific criteria.
- `delete`: Deletes an asset or folder.
- `move`: Moves or renames an asset or folder.
- `duplicate`: Makes a copy of a folder or asset.
- `exists`: Determines if a folder or asset exists.
- `list_folders`: Lists the folders contained within a folder.
- `create_folder`: Creates a folder at the specified path.

## editor_toolset.toolsets.blueprint.BlueprintTools (53)
Provides tools for working with Blueprints.

- `read_graph_dsl`: Reads a Blueprint graph and returns a DSL script.
- `write_graph_dsl`: Populates a Blueprint graph with nodes from a DSL script and compiles the Blueprint.
- `get_graph_dsl_docs`: Returns the full syntax reference for write_graph_dsl.
- `list_event_dispatchers`: Lists all event dispatchers defined on a Blueprint.
- `add_event_dispatcher`: Adds an event dispatcher to a Blueprint.
- `remove_variable`: Removes a member or local variable from a Blueprint.
- `set_variable_category`: Sets the user-defined category on a Blueprint member variable.
- `get_variable_category`: Gets the user-defined category of a Blueprint member variable.
- `set_variable_replication`: Sets the replication mode on a Blueprint member variable.
- `get_variable_replication`: Gets the replication mode of a Blueprint member variable.
- `set_variable_instance_editable`: Sets whether a member variable is editable per-instance on actors placed in the level.
- `list_variables`: Lists member or local variables defined on a Blueprint.
- `add_object_variable`: Adds a member or local variable that holds an object reference to a Blueprint.
- `add_struct_variable`: Adds a member or local variable of a struct type to a Blueprint.
- `add_variable`: Adds a member or local variable to a Blueprint.
- `set_parent`: Reparents a Blueprint to a new parent class.
- `get_parent`: Returns the parent class of a Blueprint.
- `get_pin_value`: Gets the value of a Blueprint graph pin.
- `set_pin_value`: Sets the value of a Blueprint graph pin.
- `break_pins`: Breaks the connection between two pins.
- `connect_pins`: Makes a connection between source (output) and dest (input) pins.
- `arrange_nodes`: Arranges a list of nodes in a readable left-to-right layout.
- `set_node_position`: Sets a new position for the node.
- `retarget_node_class`: Replaces a node's baked-in class reference from old_class to new_class in place.
- `remove_node_pin`: Removes a specific pin from a node that supports dynamic pin removal.
- `add_node_pin`: Adds a pin to a node that supports dynamic pin addition.
- `delete_node`: Deletes the node from its graph.
- `create_node`: Adds a new node to the graph.
- `add_component_bound_event`: Creates a component bound event node in the event graph.
- `list_component_events`: Lists the bindable delegate events available on a component.
- `find_node_categories`: Retrieves a list of available node categories in a Blueprint graph, optionally filtered by compatible input and/or output pin types
- `get_node_type_pins`: Returns the pin names and types for a node type.
- `find_node_types`: Finds node types that can be created in a particular graph meeting the search criteria.
- `get_connected_subgraph`: Returns detailed information for all nodes connected to the given node.
- `find_nodes`: Finds nodes in a graph by title, class, and/or execution role.
- `list_compatible_event_functions`: Lists functions that can be bound to a Create Event node.
- `set_create_event_function`: Binds a function to a Create Event node.
- `get_create_event_function`: Returns the function currently bound to a Create Event node.
- `get_node_infos`: Retrieves detailed information for a list of Blueprint graph nodes.
- `add_object_function_param`: Adds an object reference input or output to a function or event dispatcher.
- `add_struct_function_param`: Adds a struct input or output to a function or event dispatcher.
- `remove_function_param`: Removes an input or output from a function or event dispatcher.
- `add_function_param`: Adds an input or output to a function or event dispatcher
- `remove_function_graph`: Removes a function graph or event dispatcher from the Blueprint.
- `add_event`: Adds an event node to the Blueprint's event graph.
- `add_function_graph`: Adds a function graph to the Blueprint.
- `list_events`: Lists all events visible on the Blueprint — locally defined custom events
- `list_functions`: Lists all functions visible on the Blueprint — locally defined plus
- `get_graph`: Retrieves a specific graph from a Blueprint asset by name.
- `list_graphs`: Lists all graphs in the Blueprint.
- `get_default_object`: Returns the Class Default Object (CDO) for a Blueprint's.
- `compile_blueprint`: Compiles the given Blueprint.
- `create`: Creates a new Blueprint asset in the project.

## editor_toolset.toolsets.curve_table.CurveTableTools (9)
Provides tools for creating and editing CurveTable assets.

- `get_keys`: Returns all keys for a row.
- `set_keys`: Replaces all keys in a row with the provided list.
- `add_key`: Adds a key to a row.
- `rename_row`: Renames a row in the curve table.
- `remove_row`: Removes a row from the curve table.
- `add_row`: Adds a new row to the curve table with an optional default value.
- `list_rows`: Lists the names of all rows in the curve table.
- `create`: Creates a new CurveTable asset.
- `import_file`: Imports a file from disk as a CurveTable asset.

## editor_toolset.toolsets.data_asset.DataAssetTools (1)
Provides tools for working with Data Assets.

- `create`: Creates a new DataAsset asset in the project.

## editor_toolset.toolsets.data_table.DataTableTools (10)
Provides tools for creating and editing DataTable assets.

- `set_rows`: Sets column values for one or more rows.
- `get_rows`: Returns the column values for one or more rows as a JSON string.
- `rename_rows`: Renames one or more rows in the data table.
- `remove_rows`: Removes rows from the data table.
- `add_rows`: Adds new rows with default values to the data table.
- `list_rows`: Lists the names of all rows in the data table.
- `get_schema`: Returns the column schema of the data table as a JSON string.
- `create`: Creates a new DataTable asset with the specified column schema.
- `import_file`: Imports a file from disk as a DataTable asset.
- `search_row_structs`: Finds structs that can be used as a DataTable schema.

## editor_toolset.toolsets.material.MaterialTools (22)
Provides tools for creating and editing Material and MaterialFunction assets.

- `get_referencing_materials`: Returns asset data for all Materials that reference this MaterialFunction.
- `recompile`: Recompiles a Material or MaterialFunction after edits.
- `delete_unused_expressions`: Deletes all expression nodes not connected to any material output.
- `disconnect_from_output`: Disconnects the expression currently connected to a material output property.
- `connect_to_output`: Connects an expression node's output to one of the material's output properties.
- `get_property_input`: Returns the expression and output pin feeding a material output property.
- `get_expression_inputs`: Returns the current wiring of each input pin on a material expression.
- `disconnect_expressions`: Disconnects the input pin of an expression node, removing whatever is connected to it.
- `connect_expressions`: Connects an expression node's output pin to another expression node's input pin.
- `get_expression_output_names`: Returns the names of all output pins on a material expression node.
- `get_expression_input_names`: Returns the names of all input pins on a material expression node.
- `delete_parameter_group`: Removes a parameter group, ungrouping all parameters that belong to it.
- `rename_parameter_group`: Renames a parameter group across all parameter expressions in a Material or
- `list_parameter_groups`: Returns the unique parameter group names defined in a Material or MaterialFunction.
- `layout_expressions`: Automatically arranges all expression nodes in a Material or MaterialFunction graph.
- `get_expressions`: Returns all expression nodes in a Material or MaterialFunction graph.
- `delete_expression`: Removes an expression node from a Material or MaterialFunction graph.
- `add_expression`: Adds a new expression node to a Material or MaterialFunction graph.
- `list_expression_classes`: Returns MaterialExpression subclasses valid for the given context.
- `create_parameter_collection`: Creates a new empty MaterialParameterCollection (MPC) asset.
- `create_function`: Creates a new empty MaterialFunction asset.
- `create_material`: Creates a new empty Material asset.

## editor_toolset.toolsets.material_instance.MaterialInstanceTools (13)
Provides tools for creating and modifying MaterialInstanceConstant assets.

- `set_parameter_override`: Enables or disables a parameter override on a material instance.
- `clear_parameters`: Clears all parameter overrides on a material instance, reverting to parent defaults.
- `set_parent`: Changes the parent of a material instance.
- `set_static_switch_parameter`: Sets the value of a static switch parameter on a material instance.
- `get_static_switch_parameter`: Gets the value of a static switch parameter on a material instance.
- `set_texture_parameter`: Assigns a texture to a texture parameter on a material instance.
- `get_texture_parameter`: Gets the texture assigned to a texture parameter on a material instance.
- `set_vector_parameter`: Sets the value of a vector parameter on a material instance.
- `get_vector_parameter`: Gets the current value of a vector parameter on a material instance.
- `set_scalar_parameter`: Sets the value of a scalar parameter on a material instance.
- `get_scalar_parameter`: Gets the current value of a scalar parameter on a material instance.
- `list_parameters`: Returns all parameters exposed by a material or instance, with their names and types.
- `create`: Creates a new MaterialInstanceConstant asset derived from a parent material.

## editor_toolset.toolsets.object.ObjectTools (6)
Provides tools for inspecting and modifying the properties of

- `reset_properties`: Resets one or more properties on an object to their default values,
- `set_properties`: Sets the values of properties on an object.
- `get_properties`: Returns the values of one or more properties on an object.
- `list_properties`: Returns a list of properties that are on the specified object.
- `get_class`: Returns the class of an Unreal object.
- `search_subclasses`: Finds all subclasses of a given class.

## editor_toolset.toolsets.primitive.PrimitiveTools (4)
Provides tools for adding primitive geometry components to actors.

- `add_cone`: Adds a cone-shaped StaticMeshComponent to an actor.
- `add_cylinder`: Adds a cylinder-shaped StaticMeshComponent to an actor.
- `add_sphere`: Adds a sphere-shaped StaticMeshComponent to an actor.
- `add_cube`: Adds a cube-shaped StaticMeshComponent to an actor.

## editor_toolset.toolsets.scene.SceneTools (20)
Provides tools for working with the currently loaded level, including

- `save_actor`: Saves the actor to disk.
- `is_checked_out`: Checks whether an actor is checked out by the current user.
- `can_edit`: Checks whether an actor can be edited.
- `commit_level_instance`: Saves or discards edits to a level instance and exits edit mode.
- `edit_level_instance`: Opens a level instance for editing.
- `create_level_instance`: Creates a Level Instance actor in the scene referencing an existing level asset.
- `merge_actors`: Merges multiple StaticMesh actors into a single mesh asset and actor.
- `trace_world`: Traces a line through the world and returns the distance to the first hit.
- `delete_folder`: Deletes a folder from the outliner.
- `rename_folder`: Renames a folder in the outliner.
- `set_actor_folder`: Assigns an actor to the specified folder in the outliner.
- `get_actors_in_folder`: Returns the actors in the specified outliner folder.
- `get_folders`: Returns all folder paths currently in use in the outliner.
- `remove_from_scene`: Deletes an actor from the scene.
- `add_to_scene_from_asset`: Creates a new actor in the scene from an asset.
- `add_to_scene_from_class`: Creates a new instance of the specified object at the specified transform.
- `find_actors`: Searches the scene for actors that match specific criteria.
- `get_collision_channels`: Returns all available collision channels for use with find_actors.
- `get_current_level`: Returns the path to the current level asset.
- `load_level`: Loads a level in the editor.

## editor_toolset.toolsets.skeletal_mesh.SkeletalMeshTools (22)
Provides tools for inspecting and modifying skeletal mesh assets, including

- `rename_socket`: Renames a socket on a skeletal mesh.
- `remove_socket`: Removes a named socket from a skeletal mesh.
- `set_socket_transform`: Sets the local transform of a socket relative to its parent bone.
- `get_socket_transform`: Returns the local transform of a socket relative to its parent bone.
- `get_socket_bone`: Returns the name of the bone that a socket is attached to.
- `get_socket_names`: Returns the names of all sockets on a skeletal mesh.
- `add_socket`: Adds a named socket to a skeletal mesh attached to a bone.
- `get_morph_target_names`: Returns the names of all morph targets on a skeletal mesh.
- `assign_physics_asset`: Assigns a physics asset to a skeletal mesh.
- `get_physics_asset`: Returns the physics asset assigned to a skeletal mesh.
- `set_material`: Assigns a material to a named slot on a skeletal mesh asset.
- `get_material`: Returns the material assigned to a named slot on a skeletal mesh.
- `get_material_slots`: Returns the names of all material slots in a skeletal mesh.
- `get_bone_children`: Returns the direct children of a bone.
- `get_bone_parent`: Returns the name of a bone's parent, or an empty string for the root bone.
- `get_bone_names`: Returns the names of all bones in a skeletal mesh in hierarchy order.
- `get_skeleton`: Returns the skeleton asset associated with a skeletal mesh.
- `get_bounds`: Returns the local-space bounding volume of a skeletal mesh.
- `get_section_count`: Returns the number of sections in a specific LOD of a skeletal mesh.
- `get_vertex_count`: Returns the number of vertices in a specific LOD of a skeletal mesh.
- `get_lod_count`: Returns the number of LODs in a skeletal mesh asset.
- `import_file`: Imports a mesh file from disk as a SkeletalMesh asset.

## editor_toolset.toolsets.static_mesh.StaticMeshTools (16)
Provides tools for inspecting and modifying static mesh assets.

- `set_nanite_enabled`: Enables or disables Nanite for a static mesh.
- `is_nanite_enabled`: Returns whether Nanite is enabled for a static mesh.
- `remove_collisions`: Removes all collision shapes from a static mesh.
- `generate_convex_collisions`: Generates convex hull collision shapes for a static mesh.
- `remove_lods`: Removes all auto-generated LODs from a static mesh, keeping only LOD 0.
- `generate_lods`: Auto-generates LODs for a static mesh using triangle reduction.
- `set_lod_thresholds`: Sets the screen-size thresholds at which each LOD becomes active.
- `get_lod_thresholds`: Returns the screen-size thresholds at which each LOD becomes active.
- `set_material`: Assigns a material to a named slot on a static mesh asset.
- `get_material`: Returns the material assigned to a named slot on a static mesh.
- `get_material_slots`: Returns the names of all material slots in a static mesh.
- `get_bounds`: Returns the local-space bounding box of a static mesh.
- `get_vertex_count`: Returns the number of vertices in a specific LOD of a static mesh.
- `get_triangle_count`: Returns the number of triangles in a specific LOD of a static mesh.
- `get_lod_count`: Returns the number of LODs in a static mesh asset.
- `import_file`: Imports a mesh file from disk as a StaticMesh asset.

## editor_toolset.toolsets.string_table.StringTableTools (8)
Provides tools for creating and editing StringTable assets.

- `remove_entry`: Removes an entry from the string table.
- `set_entry`: Adds or updates an entry in the string table.
- `get_entry`: Returns the source string for a specific key.
- `list_keys`: Lists all keys in the string table.
- `get_namespace`: Returns the namespace of a StringTable asset.
- `get_table_id`: Returns the table ID for a StringTable asset.
- `create`: Creates a new StringTable asset.
- `import_file`: Imports a file from disk as a StringTable asset.

## editor_toolset.toolsets.programmatic.ProgrammaticToolset (2)
Batches calls to other registered tools through a small sandboxed Python

- `execute_tool_script`: Execute a Python script against the toolset APIs.
- `get_execution_environment`: Get details about execution environment.

## editor_toolset.toolsets.texture.TextureTools (2)
Provides tools for working with Texture assets.

- `get_size`: Returns the dimensions of a Texture2D in pixels.
- `import_file`: Imports an image file from disk as a Texture2D asset.

## animation_toolset.toolsets.controlrig.ControlRigTools (44)
Tools for creating and editing Control Rig assets, including hierarchy

- `remove_variable`: Remove a member variable from the Control Rig.
- `change_variable_type`: Change the type of an existing variable.
- `get_variable`: Get a specific variable by name.
- `list_variables`: List all member variables in the Control Rig.
- `add_variable`: Add a member variable to the Control Rig.
- `get_connected_pins`: Get all pins connected to this pin.
- `disconnect_pins`: Disconnect two pins.
- `connect_pins`: Connect two pins together.
- `set_pin_value`: Set the default value of a pin.
- `get_pin_value`: Get the default value of a pin.
- `list_pins`: List all pins on a node.
- `add_variable_node`: Create a variable getter or setter node.
- `add_event_node`: Add an event node to the graph.
- `set_node_position`: Set the position of a node in the graph editor.
- `get_node_position`: Get the position of a node in the graph editor.
- `delete_node`: Delete a node from the graph.
- `list_nodes`: List all nodes in a graph.
- `create_node`: Create a new RigUnit node in the graph.
- `add_interaction_graph`: Create an interaction graph with InteractionExecution event.
- `add_backward_solve_graph`: Create a backward solve graph with InverseExecution event.
- `add_event_graph`: Create a new graph with the specified event type.
- `get_interaction_graph`: Get the interaction graph.
- `get_backward_solve_graph`: Get the backward solve graph.
- `get_event_graph`: Get a graph containing the specified event type.
- `get_forward_solve_graph`: Get the forward solve graph (main execution graph).
- `add_graph`: Create a new empty graph in the Control Rig.
- `list_graphs`: List all graphs in the Control Rig.
- `get_graph`: Get a specific graph from the Control Rig by name.
- `get_children`: Get children of a hierarchy element.
- `get_parent`: Get the parent of a hierarchy element.
- `set_local_transform`: Set local transform of a hierarchy element.
- `get_local_transform`: Get local transform of a hierarchy element.
- `set_global_transform`: Set global transform of a hierarchy element.
- `get_global_transform`: Get global transform of a hierarchy element.
- `add_control`: Add a control to the hierarchy.
- `add_null`: Add a null (locator) to the Control Rig hierarchy.
- `add_bone`: Add a bone to the Control Rig hierarchy.
- `add_element`: Add a bone or null element to the Control Rig hierarchy.
- `get_all_controls`: Get all controls in the Control Rig hierarchy.
- `get_all_nulls`: Get all nulls (locators) in the Control Rig hierarchy.
- `get_all_bones`: Get all bones in the Control Rig hierarchy.
- `get_elements`: Get hierarchy elements of the specified type.
- `import_bones_from_asset`: Import bones from the given skeletal mesh to the Control Rig hierarchy.
- `create`: Creates a new Control Rig at the given location.

## animation_toolset.toolsets.sequencer.SequencerTools (140)
Core tools for creating and editing Level Sequences in Sequencer. Use

- `paste_folders`: Paste folders from the clipboard into the sequence.
- `copy_folders`: Copy one or more folders to the Sequencer clipboard.
- `paste_sections`: Paste sections from the clipboard onto the given tracks.
- `copy_sections`: Copy one or more sections to the Sequencer clipboard.
- `paste_tracks`: Paste tracks from the clipboard onto the given bindings.
- `copy_tracks`: Copy one or more tracks to the Sequencer clipboard.
- `paste_bindings`: Paste bindings from the clipboard (or a token returned by copy_bindings).
- `copy_bindings`: Copy one or more bindings to the Sequencer clipboard.
- `remove_binding_tag`: Remove a tag from the sequence entirely.
- `untag_binding`: Remove a tag from a binding.
- `tag_binding`: Attach a tag to a binding.
- `get_binding_tags`: Get the tags currently attached to a specific binding.
- `get_all_binding_tags`: Get every tag name registered in the sequence.
- `find_bindings_by_tag`: Find all bindings with the given tag in the sequence.
- `find_binding_by_tag`: Find the first binding with the given tag in the sequence.
- `get_section_post_roll_frames`: Get the number of post-roll frames configured on a section.
- `set_section_post_roll_frames`: Set the number of frames to post-roll this section after it ends.
- `get_section_pre_roll_frames`: Get the number of pre-roll frames configured on a section.
- `set_section_pre_roll_frames`: Set the number of frames to pre-roll this section before it starts.
- `set_section_animation`: Set the animation asset on a skeletal animation section.
- `set_byte_track_enum`: Configure a byte track to use a specific enum type.
- `set_property_name_and_path`: Configure a property track to animate a specific UProperty.
- `get_section_to_key`: Get the active section that receives new keys on a track.
- `get_binding_id`: Get the binding ID for a binding proxy.
- `get_child_possessables`: Get component bindings under an actor binding.
- `bake_transform`: Bake transforms for the given bindings at every frame.
- `set_sequence_locked`: Lock or unlock the current sequence and its descendants.
- `is_sequence_locked`: Check if the current sequence and its descendants are locked.
- `set_track_filter_active`: Enable or disable a track filter.
- `is_track_filter_active`: Check whether a track filter is currently active.
- `get_track_filter_names`: Get all available track filter names.
- `fix_actor_references`: Attempt to auto-fix broken actor references in the current sequence.
- `rebind_component`: Rebind component bindings to a named component.
- `remove_invalid_bindings`: Remove missing or broken actor references from a binding.
- `remove_all_bindings`: Remove all bound actors from a binding.
- `remove_actors_from_binding`: Remove specific actors from a binding.
- `replace_binding_with_actors`: Replace all bound actors on a binding with new ones.
- `add_actors_to_binding`: Add actors to an existing binding.
- `add_event_repeater_section`: Add an event repeater section to an event track.
- `add_event_trigger_section`: Add an event trigger section to an event track.
- `get_sequence_lock_state`: Check whether the current level sequence is locked.
- `get_sub_sequence_hierarchy`: Get the current sub-sequence hierarchy path.
- `focus_parent_sequence`: Navigate up one level in the sub-sequence hierarchy.
- `focus_sub_sequence`: Navigate into a sub-sequence via its sub-section.
- `get_folder_contents`: Get the tracks and bindings inside a folder.
- `add_binding_to_folder`: Add a binding into a folder for organization.
- `add_track_to_folder`: Add a track into a folder for organization.
- `remove_root_folder`: Remove a root-level folder from the sequence.
- `get_root_folders`: Get all root-level folders in the sequence.
- `add_root_folder`: Create a new root-level folder in the sequence.
- `add_actors_by_name`: Add actors to the sequence by their names in the level.
- `set_selection_range`: Set the selection range (green bar) start and end frames.
- `get_selection_range`: Get the selection range (green bar) start and end frames.
- `play_to`: Play from the current position to a specific frame, then stop.
- `is_camera_cut_locked`: Check if the camera cut is locked to the viewport.
- `select_folders`: Set the folder selection in the Sequencer editor.
- `set_camera_lock`: Lock or unlock the camera cut to the viewport.
- `force_evaluate`: Force the Sequencer to evaluate and update the viewport.
- `empty_selection`: Clear all selection in the Sequencer editor.
- `select_bindings`: Set the binding selection in the Sequencer editor.
- `select_sections`: Set the section selection in the Sequencer editor.
- `select_tracks`: Set the track selection in the Sequencer editor.
- `get_selected_folders`: Get the currently selected folders in the Sequencer editor.
- `get_selected_bindings`: Get the currently selected bindings in the Sequencer editor.
- `get_selected_sections`: Get the currently selected sections in the Sequencer editor.
- `get_selected_tracks`: Get the currently selected tracks in the Sequencer editor.
- `get_section_properties`: Get all common properties of a section in a single call.
- `get_section_completion_mode`: Get the completion mode of a section.
- `set_section_completion_mode`: Set the completion mode of a section.
- `get_section_blend_type`: Get the blend type of a section.
- `set_section_blend_type`: Set the blend type of a section.
- `get_section_ease_out`: Get the effective ease-out duration of a section in frames.
- `get_section_ease_in`: Get the effective ease-in duration of a section in frames.
- `set_section_ease_out`: Set the ease-out duration of a section in frames.
- `set_section_ease_in`: Set the ease-in duration of a section in frames.
- `set_camera_cut_binding`: Set which camera a camera cut section uses.
- `set_section_end_bounded`: Set whether the section end frame is bounded or infinite.
- `set_section_start_bounded`: Set whether the section start frame is bounded or infinite.
- `has_section_end_frame`: Check if a section has a bounded end frame (vs infinite).
- `has_section_start_frame`: Check if a section has a bounded start frame (vs infinite).
- `get_section_range`: Get the frame range of a section.
- `set_section_range`: Set the frame range of a section.
- `remove_section`: Remove a section from a track.
- `get_sections`: Get all sections on a track.
- `add_section`: Add a new section to a track.
- `set_track_display_name`: Set the display name of a track.
- `get_track_display_name`: Get the display name of a track.
- `remove_track_from_sequence`: Remove a sequence-level (master) track.
- `remove_track`: Remove a track from a binding.
- `find_tracks_by_type`: Find all tracks of a specific type on a binding.
- `get_tracks_on_sequence`: Get all sequence-level (master) tracks.
- `get_tracks_on_binding`: Get all tracks on a binding.
- `add_track_to_sequence`: Add a sequence-level (master) track.
- `add_track_to_binding`: Add a track of the given type to a binding.
- `get_bound_objects`: Get the objects currently resolved by a binding.
- `remove_binding`: Remove a binding from the sequence.
- `set_binding_name`: Set the display name of a binding.
- `get_binding_name`: Get the display name of a binding.
- `find_binding_by_name`: Find a binding by its display name.
- `get_bindings`: Get all bindings in the sequence.
- `create_camera`: Create a new cine camera actor in the sequence.
- `add_spawnable_from_class`: Create a spawnable binding from an actor class.
- `add_spawnable_from_instance`: Create a spawnable binding from an existing object instance.
- `add_actors`: Add actors from the level to the currently open sequence.
- `set_playback_range_locked`: Lock or unlock the playback range.
- `is_playback_range_locked`: Check if the playback range is locked.
- `set_clock_source`: Set the clock source for the sequence.
- `get_clock_source`: Get the clock source for the sequence.
- `set_evaluation_type`: Set the evaluation type of a sequence.
- `get_evaluation_type`: Get the evaluation type of a sequence.
- `set_tick_resolution`: Set the internal tick resolution of a sequence.
- `get_tick_resolution`: Get the internal tick resolution of a sequence.
- `find_marked_frame_by_label`: Find a marked frame by label.
- `delete_all_marked_frames`: Delete all marked frames from the sequence.
- `delete_marked_frame`: Delete a marked frame by index.
- `get_marked_frames`: Get all marked frames (bookmarks) in the sequence.
- `add_marked_frame`: Add a marked frame (bookmark) to the sequence.
- `get_work_range`: Get the work range of the sequence.
- `set_work_range`: Set the work range of the sequence.
- `get_view_range`: Get the visible time range in the Sequencer timeline.
- `set_view_range`: Set the visible time range in the Sequencer timeline.
- `set_playback_range`: Set the playback start and end frames of a sequence.
- `get_playback_range`: Get the playback start and end frames of a sequence.
- `set_display_rate`: Set the display frame rate of a sequence.
- `get_display_rate`: Get the display frame rate of a sequence.
- `get_loop_mode`: Get the current loop playback mode.
- `set_loop_mode`: Enable or disable loop playback.
- `get_playback_speed`: Get the current playback speed multiplier.
- `set_playback_speed`: Set the playback speed multiplier.
- `get_playhead_frame`: Get the current playhead position in display rate frames.
- `set_playhead_frame`: Set the playhead position in display rate frames.
- `is_playing`: Check whether the sequence is currently playing.
- `pause`: Pause playback of the current sequence.
- `play`: Start playback of the current sequence.
- `refresh_sequence`: Force refresh the Sequencer editor UI on the next tick.
- `close_sequence`: Close the currently open level sequence editor.
- `open_sequence`: Open a level sequence asset in the Sequencer editor.
- `get_focused_sequence`: Get the currently focused level sequence in the hierarchy.
- `get_current_sequence`: Get the root level sequence currently open in the Sequencer editor.
- `create_level_sequence`: Create a new Level Sequence asset.

## animation_toolset.toolsets.keyframing.SequencerKeyframingTools (22)
Tools for keyframing and animating properties on the Sequencer

- `get_keys_by_index`: Get specific keys on a channel by their indices, returned as JSON.
- `bake_channel_keys`: Bake a channel's values over a frame range.
- `is_curve_shown`: Check if a curve is visible in the Curve Editor.
- `show_curve`: Show or hide a curve in the Curve Editor.
- `curve_editor_empty_selection`: Clear all key selection in the Curve Editor.
- `curve_editor_select_keys`: Select keys by index in the Curve Editor.
- `get_curve_editor_selected_keys`: Get selected key indices for a channel in the Curve Editor.
- `get_selected_key_channels`: Get channels that have selected keys in the Curve Editor.
- `is_curve_editor_open`: Check whether the Curve Editor panel is currently open.
- `close_curve_editor`: Close the Sequencer Curve Editor panel.
- `open_curve_editor`: Open the Sequencer Curve Editor panel.
- `select_channels`: Set the channel selection in the Sequencer editor.
- `get_selected_channels`: Get the currently selected channels in the Sequencer editor.
- `get_default_value`: Get the default value of a float channel.
- `set_default_value`: Set the default value of a channel.
- `remove_key_at_frame`: Remove a key at a specific frame from a channel.
- `get_keys`: Get all keys on a channel, returned as a JSON array.
- `add_key_string`: Add a string key to a channel on a section.
- `add_key_integer`: Add an integer key to a channel on a section.
- `add_key_bool`: Add a bool key to a channel on a section.
- `add_key_float`: Add a float key to a channel on a section.
- `get_channel_names`: Get the names of all channels on a section.

## animation_toolset.toolsets.controlrig_sequencer.SequencerControlRigTools (72)
Tools for animating with Control Rig inside Sequencer. Use when adding

- `set_anim_mode_local_spaces`: Toggle multi-select transforms acting in each control's own space.
- `get_anim_mode_local_spaces`: Get whether multi-select transforms act in each control's own space.
- `set_anim_mode_only_rig_sel`: Toggle Animation Mode restricting viewport selection to rig controls.
- `get_anim_mode_only_rig_sel`: Get whether Animation Mode restricts viewport selection to rig controls.
- `set_anim_mode_hide_manips`: Toggle whether Animation Mode hides all manipulators.
- `get_anim_mode_hide_manips`: Get whether Animation Mode hides all manipulators.
- `set_anim_mode_nulls`: Toggle the Animation Mode nulls display.
- `get_anim_mode_nulls`: Get whether the Animation Mode draws nulls.
- `set_anim_mode_hierarchy`: Toggle the Animation Mode hierarchy lines/dots display.
- `get_anim_mode_hierarchy`: Get whether the Animation Mode draws hierarchy lines/dots.
- `set_anim_mode_gizmo_scale`: Set the editor's transform gizmo size.
- `get_anim_mode_gizmo_scale`: Get the editor's transform gizmo size.
- `get_transform`: Get the transform value of a Control Rig control at a frame.
- `set_transform`: Set a transform value on a Control Rig control and optionally key it.
- `get_controls_info`: Get all controls on a Control Rig with their names and types.
- `get_control_rigs`: Get all Control Rigs currently in the sequence.
- `find_or_create_track`: Add a Control Rig track to a binding using a Control Rig asset.
- `import_fbx_to_rig`: Import an FBX file onto a Control Rig track.
- `export_fbx_from_rig`: Export an FBX file from a Control Rig section.
- `frame_selection`: Frame the viewport to the current Control Rig control selection.
- `clear_selection`: Clear the current Control Rig control selection.
- `select_control`: Select or deselect a control on a Control Rig.
- `get_selected_controls`: Get the currently selected controls on a Control Rig.
- `zero_transforms`: Reset Control Rig transforms to their default (usually zero) values.
- `mirror_selected_controls`: Apply a mirrored pose to the currently selected controls.
- `select_mirrored_controls`: Select the mirrored counterparts of the currently selected controls.
- `merge_anim_layers`: Merge specified animation layers into one.
- `reorder_anim_layers`: Move an animation layer from one index to another.
- `duplicate_anim_layer`: Duplicate an animation layer at the specified index.
- `delete_anim_layer`: Delete an animation layer at the specified index.
- `add_layer_from_selection`: Add an animation layer from the currently selected objects in Sequencer.
- `get_anim_layers`: Get all animation layers from the active Sequencer.
- `snap_control_rig`: Snap Control Rig controls to a target actor over a frame range.
- `blend_values_on_selected`: Perform a blend operation on selected keys or controls.
- `tween_control_rig`: Perform a tween operation on a Control Rig at the current Sequencer time.
- `bake_space`: Bake Control Rig controls' space over a frame range.
- `delete_space`: Delete a space-switch key at a specific frame.
- `move_space`: Move a space-switch key from one frame to another.
- `set_space`: Set the space for a Control Rig control at a given frame.
- `is_fk_control_rig`: Check if a Control Rig is an FK Control Rig.
- `set_priority_order`: Set the evaluation priority order of a Control Rig track.
- `get_priority_order`: Get the evaluation priority order of a Control Rig track.
- `set_layered_mode`: Set a Control Rig track to layered or absolute mode.
- `is_layered_control_rig`: Check if a Control Rig in the sequence is in layered mode.
- `hide_all_controls`: Hide all controls on a Control Rig section (mask everything).
- `show_all_controls`: Show all controls on a Control Rig section (unmask everything).
- `set_controls_mask`: Set the visibility mask for the specified controls on a section.
- `get_controls_mask`: Check if a control is visible (unmasked) on a section.
- `collapse_anim_layers`: Collapse all sections and layers on a Control Rig track into one section.
- `load_anim_into_rig`: Load an animation sequence into a Control Rig section.
- `bake_to_control_rig`: Bake existing animation on a binding into a Control Rig track.
- `key_controls_at_frames`: Key the specified controls at specific frame numbers.
- `key_controls`: Key the specified controls on the section at the current Sequencer time.
- `get_actor_transform_at_frame`: Get an actor's world transform at a specific frame.
- `set_world_transform`: Set a control's world-space transform at a specific frame.
- `get_world_transform`: Get a control's world-space transform at a specific frame.
- `set_euler_transform`: Set an EulerTransform control value at a specific frame.
- `get_euler_transform`: Get an EulerTransform control value at a specific frame.
- `set_scale`: Set a scale control value at a specific frame.
- `get_scale`: Get a scale control value at a specific frame.
- `set_rotator`: Set a rotator control value at a specific frame.
- `get_rotator`: Get a rotator control value at a specific frame.
- `set_position`: Set a position control value at a specific frame.
- `get_position`: Get a position control value at a specific frame.
- `set_vector2d`: Set a Vector2D control value at a specific frame.
- `get_vector2d`: Get a Vector2D control value at a specific frame.
- `set_int`: Set an integer control value at a specific frame.
- `get_int`: Get an integer control value at a specific frame.
- `set_bool`: Set a bool control value at a specific frame.
- `get_bool`: Get a bool control value at a specific frame.
- `set_float`: Set a float control value at a specific frame.
- `get_float`: Get a float control value at a specific frame.

## animation_toolset.toolsets.outliner.SequencerOutlinerTools (18)
Tools for inspecting and managing the Sequencer outliner tree. Use when

- `get_sections_for_nodes`: Get sections associated with the given outliner nodes.
- `get_pinned_nodes`: Get the currently pinned outliner nodes.
- `set_node_pinned`: Pin or unpin outliner nodes.
- `get_locked_nodes`: Get the currently locked outliner nodes.
- `set_node_locked`: Lock or unlock outliner nodes for editing.
- `get_deactivated_nodes`: Get the currently deactivated outliner nodes.
- `set_node_deactivated`: Deactivate or reactivate outliner nodes.
- `get_soloed_nodes`: Get the currently soloed outliner nodes.
- `get_muted_nodes`: Get the currently muted outliner nodes.
- `set_node_solo`: Solo or unsolo outliner nodes.
- `set_node_muted`: Mute or unmute outliner nodes.
- `is_node_expanded`: Check whether an outliner node is expanded.
- `set_node_expanded`: Expand or collapse outliner nodes.
- `get_node_label`: Get the display label of an outliner node.
- `set_outliner_selection`: Set the outliner selection.
- `get_outliner_selection`: Get the currently selected nodes in the outliner.
- `get_outliner_children`: Get child nodes of an outliner node.
- `get_outliner_tree`: Get a full snapshot of the Sequencer outliner tree.

## animation_toolset.toolsets.conditions.SequencerConditionTools (9)
Tools for managing runtime conditions on Sequencer tracks, sections, and

- `clear_track_row_condition`: Remove the condition from a specific track row.
- `set_track_row_condition`: Set a condition on a specific track row.
- `get_track_row_condition`: Get the condition on a specific track row.
- `clear_track_condition`: Remove the condition from a track.
- `set_track_condition`: Set a condition on a track.
- `get_track_condition`: Get the track-level condition.
- `clear_section_condition`: Remove the condition from a section.
- `set_section_condition`: Set a condition on a section.
- `get_section_condition`: Get the condition on a section.

## animation_toolset.toolsets.custom_bindings.SequencerCustomBindingTools (8)
Tools for converting and managing custom binding types in Sequencer. Use

- `save_default_spawnable_state`: Save the current state of a spawnable as its default.
- `change_actor_template_class`: Set the actor class for a spawnable or replaceable template.
- `get_custom_bindings_of_type`: Find all bindings of a given custom type in the current sequence.
- `get_custom_binding_objects`: Get the custom binding instances for a binding.
- `get_custom_binding_type`: Get the custom binding class for a binding.
- `convert_to_custom_binding`: Convert a binding to a custom binding type.
- `convert_to_possessable`: Convert a spawnable binding to a possessable.
- `convert_to_spawnable`: Convert a possessable binding to a spawnable.

## animation_toolset.toolsets.import_export.SequencerImportExportTools (6)
Tools for importing and exporting animation data to and from Sequencer.

- `get_linked_level_sequence`: Get the content path of the LevelSequence linked to an AnimSequence.
- `get_linked_anim_sequences`: Get content paths of all AnimSequences linked to a LevelSequence.
- `link_anim_sequence`: Link an AnimSequence asset to a level sequence binding.
- `export_anim_sequence`: Export animation from a sequence binding to an AnimSequence asset.
- `import_fbx`: Import FBX data into a level sequence.
- `export_fbx`: Export a level sequence to FBX.

## aimodule_toolset.toolsets.behavior_tree.BehaviorTreeTools (7)
Inspect BehaviorTree (BT) assets.

- `get_subtree`: Returns the sub-BT asset referenced by a RunBehavior task.
- `get_children`: Returns direct child nodes of a composite node.
- `get_node_depths`: Returns tree depths for all nodes, matching list_nodes order.
- `get_node_depth`: Returns the tree depth of a node by its list_nodes index.
- `list_nodes`: Returns a flat list of all node UObjects in tree order.
- `get_root_decorators`: Returns root-level decorators on this tree.
- `get_blackboard`: Returns the blackboard asset for this behavior tree.
