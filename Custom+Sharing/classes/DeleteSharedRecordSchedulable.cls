global class DeleteSharedRecordSchedulable implements Schedulable 
{
    global void execute(SchedulableContext ctx) 
    {
        try {
            // Query Shared Records with expiry date as today
            List<Shared_Record__c> sharedRecords = [
                SELECT Id, RecordId__c 
                FROM Shared_Record__c 
                WHERE Expiry_Date__c = TODAY
            ];

            if (!sharedRecords.isEmpty()) {
                List<Id> recordIdsToDelete = new List<Id>();
                Map<Id, Id> sharedRecordMap = new Map<Id, Id>(); // Map RecordId__c -> Shared_Record__c Id

                for (Shared_Record__c sr : sharedRecords) {
                    if (sr.RecordId__c != null) {
                        recordIdsToDelete.add(sr.RecordId__c);
                        sharedRecordMap.put(sr.RecordId__c, sr.Id);
                    }
                }

                System.debug('Record IDs to delete: ' + recordIdsToDelete);

                // Delete referenced records first
                if (!recordIdsToDelete.isEmpty()) {
                    Database.DeleteResult[] deleteResults = Database.delete(recordIdsToDelete, false);
                    List<Id> sharedRecordsToDelete = new List<Id>();

                    for (Integer i = 0; i < deleteResults.size(); i++) {
                        if (deleteResults[i].isSuccess()) {
                            Id deletedRecordId = recordIdsToDelete[i];
                            sharedRecordsToDelete.add(sharedRecordMap.get(deletedRecordId)); // Get associated Shared_Record__c Id
                        } else {
                            for (Database.Error err : deleteResults[i].getErrors()) {
                                System.debug('Failed to delete referenced record ID: ' + recordIdsToDelete[i] + ' Error: ' + err.getMessage());
                            }
                        }
                    }

                    // Delete only the successfully deleted referenced records' Shared_Record__c
                    if (!sharedRecordsToDelete.isEmpty()) {
                        Database.DeleteResult[] deleteSharedResults = Database.delete(sharedRecordsToDelete, false);
                        for (Integer i = 0; i < deleteSharedResults.size(); i++) {
                            if (!deleteSharedResults[i].isSuccess()) {
                                for (Database.Error err : deleteSharedResults[i].getErrors()) {
                                    System.debug('Failed to delete Shared_Record__c ID: ' + sharedRecordsToDelete[i] + ' Error: ' + err.getMessage());
                                }
                            }
                        }
                        System.debug('Successfully deleted ' + sharedRecordsToDelete.size() + ' Shared_Record__c records.');
                    }
                }
            }
        } catch (Exception e) {
            System.debug('Error in ScheduleDeleteSharedRecord: ' + e.getMessage());
        }
    }
}