public class SharingRecordHandler 
{
    @AuraEnabled
    public static String createSharingRecord(String recordIdString, Id userId, String selectedAccessLevel, Date expiryDate) 
    {
        Id recordId = Id.valueOf(recordIdString);
        String objectApiName = recordId.getSObjectType().getDescribe().getName();
        System.debug('🔹 Object API Name: ' + objectApiName);
        
        Boolean isCustomObject = objectApiName.endsWith('__c');
        String shareObjectName = isCustomObject ? objectApiName.replace('__c', '__Share') : objectApiName + 'Share';
        String accessFieldName = isCustomObject ? 'AccessLevel' : objectApiName + 'AccessLevel';
        String recordIdFieldName = isCustomObject ? 'ParentId' : objectApiName + 'Id'; // Fixed variable name
        
        System.debug('🔹 Share Object Name: ' + shareObjectName);
        System.debug('🔹 Access Field Name: ' + accessFieldName);

        // Check if the Share object exists
        if (!Schema.getGlobalDescribe().containsKey(shareObjectName)) 
        {
            System.debug('⚠️ ERROR: Share object ' + shareObjectName + ' does not exist. Ensure the object supports sharing.');
            return 'Error: Share object does not exist';
        }

        try
        {
            List<Shared_Record__c> existingRecords = [
                SELECT Id FROM Shared_Record__c WHERE Object_Record_Id__c = :recordId AND User_Id__c = :userId
            ];
            if (!existingRecords.isEmpty())
            {
                return 'Error: Sharing already exists.';
            } 
            else 
            {
                // Create a sharing record
                SObject shareRecord = Schema.getGlobalDescribe().get(shareObjectName).newSObject();
                shareRecord.put(recordIdFieldName, recordId);
                shareRecord.put('UserOrGroupId', userId);
                shareRecord.put(accessFieldName, selectedAccessLevel);
                shareRecord.put('RowCause', 'Manual'); // Ensure RowCause is valid
                insert shareRecord;
                
                // Create a record in Shared_Record__c object
                Shared_Record__c newRecord = new Shared_Record__c();
                newRecord.RecordId__c = shareRecord.Id; // Make sure this field correctly refers to the shared record
                newRecord.Object_Record_Id__c = recordId;
                newRecord.User_Id__c = userId;
                newRecord.Expiry_Date__c = expiryDate;
                insert newRecord;
                
                return 'Success'; 
            }
        } 
        catch (Exception e) 
        {
            System.debug('❌ Error creating sharing record: ' + e.getMessage());
            return 'Error: ' + e.getMessage();
        }
    }
}