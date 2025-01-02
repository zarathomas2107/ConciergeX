import openai
from typing import Optional
import json
import os
from datetime import datetime

class FineTuningManager:
    def __init__(self, base_model: str = "gpt-3.5-turbo"):
        self.base_model = base_model
        self.current_job = None

    async def start_fine_tuning(self, training_file: str) -> str:
        """Start fine-tuning process with the provided training data"""
        try:
            # Upload the file
            with open(training_file, 'rb') as f:
                response = await openai.File.acreate(
                    file=f,
                    purpose='fine-tune'
                )
            file_id = response.id

            # Create fine-tuning job
            job = await openai.FineTuningJob.acreate(
                training_file=file_id,
                model=self.base_model,
                hyperparameters={
                    "n_epochs": 3
                }
            )
            
            self.current_job = job.id
            return job.id
        except Exception as e:
            print(f"Error starting fine-tuning: {e}")
            raise

    async def check_status(self, job_id: Optional[str] = None) -> dict:
        """Check the status of a fine-tuning job"""
        try:
            job_id = job_id or self.current_job
            if not job_id:
                raise ValueError("No fine-tuning job ID provided")

            job = await openai.FineTuningJob.aretrieve(job_id)
            return {
                "status": job.status,
                "trained_tokens": job.trained_tokens,
                "error": job.error,
                "fine_tuned_model": job.fine_tuned_model
            }
        except Exception as e:
            print(f"Error checking fine-tuning status: {e}")
            raise

    def save_model_info(self, model_info: dict):
        """Save fine-tuned model information"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"model_info_{timestamp}.json"
        
        with open(filename, 'w') as f:
            json.dump(model_info, f, indent=2)
        
        return filename 