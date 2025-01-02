from langchain.callbacks.base import BaseCallbackHandler
import wandb
import json
from datetime import datetime
from typing import Dict, Any, List, Optional
import os

class SearchTrainingCallback(BaseCallbackHandler):
    def __init__(self, log_dir: str = "training_data", use_wandb: bool = False):
        super().__init__()
        self.log_dir = log_dir
        self.use_wandb = use_wandb
        self.current_interaction = {
            "query": "",
            "steps": [],
            "final_result": None,
            "timestamp": None,
            "success": False
        }
        os.makedirs(log_dir, exist_ok=True)
        
        # Initialize wandb for tracking if enabled
        self.run = None
        if self.use_wandb:
            try:
                self.run = wandb.init(
                    project="restaurant-search",
                    config={
                        "model": "gpt-4",
                        "temperature": 0
                    }
                )
            except Exception as e:
                print(f"Warning: Failed to initialize wandb: {e}")
                self.use_wandb = False

    def _log_to_wandb(self, data: Dict[str, Any]):
        """Helper method to safely log to wandb"""
        if self.use_wandb:
            try:
                wandb.log(data)
            except Exception as e:
                print(f"Warning: Failed to log to wandb: {e}")

    def on_chain_start(self, serialized: Dict[str, Any], inputs: Dict[str, Any], **kwargs):
        self.current_interaction["query"] = inputs.get("input", "")
        self.current_interaction["timestamp"] = datetime.now().isoformat()
        
        self._log_to_wandb({
            "query": inputs.get("input", ""),
            "event": "chain_start"
        })

    def on_tool_start(self, serialized: Dict[str, Any], input_str: str, **kwargs):
        step = {
            "tool": serialized.get("name", "unknown_tool"),
            "input": input_str,
            "output": None,
            "timestamp": datetime.now().isoformat()
        }
        self.current_interaction["steps"].append(step)
        
        self._log_to_wandb({
            "tool_name": step["tool"],
            "tool_input": input_str,
            "event": "tool_start"
        })

    def on_tool_end(self, output: str, **kwargs):
        if self.current_interaction["steps"]:
            self.current_interaction["steps"][-1]["output"] = output
            
            self._log_to_wandb({
                "tool_name": self.current_interaction["steps"][-1]["tool"],
                "tool_output": output,
                "event": "tool_end"
            })

    def on_chain_end(self, outputs: Dict[str, Any], **kwargs):
        self.current_interaction["final_result"] = outputs
        self.current_interaction["success"] = "error" not in outputs
        self._save_interaction()
        
        self._log_to_wandb({
            "success": self.current_interaction["success"],
            "event": "chain_end",
            "outputs": outputs
        })

    def on_chain_error(self, error: str, **kwargs):
        self.current_interaction["error"] = str(error)
        self._save_interaction()
        
        self._log_to_wandb({
            "error": str(error),
            "event": "chain_error"
        })

    def _save_interaction(self):
        try:
            filename = os.path.join(
                self.log_dir,
                f"interaction_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
            )
            with open(filename, 'w') as f:
                json.dump(self.current_interaction, f, indent=2)
        except Exception as e:
            print(f"Warning: Failed to save interaction: {e}")

class TrainingDataCollector:
    def __init__(self, project_name: str = "restaurant-search", use_wandb: bool = False):
        self.search_callback = SearchTrainingCallback(use_wandb=use_wandb)
        self.callbacks = [self.search_callback]

    def prepare_fine_tuning_data(self, log_dir: str = "training_data") -> str:
        """Convert collected data into fine-tuning format"""
        fine_tuning_data = []
        
        try:
            for filename in os.listdir(log_dir):
                if not filename.endswith('.json'):
                    continue
                    
                with open(os.path.join(log_dir, filename)) as f:
                    interaction = json.load(f)
                    
                if interaction.get("success"):
                    fine_tuning_data.append({
                        "messages": [
                            {"role": "system", "content": "You are a restaurant search assistant."},
                            {"role": "user", "content": interaction["query"]},
                            {"role": "assistant", "content": json.dumps(interaction["final_result"])}
                        ]
                    })

            output_file = "fine_tuning_data.jsonl"
            with open(output_file, 'w') as f:
                for item in fine_tuning_data:
                    f.write(json.dumps(item) + '\n')

            return output_file
        except Exception as e:
            print(f"Error preparing fine-tuning data: {e}")
            return "" 